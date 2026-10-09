// File: android/app/src/main/java/com/example/soundpilot_application/GainPlayer.java
//
// Plays a mono sound source on both ears with separate left and right gains,
// optionally on one output device. Used for the calibration test tone and the
// test exercise (see MainActivity).

package com.example.soundpilot_application;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioTrack;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.util.Log;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.ShortBuffer;

final class GainPlayer {

    private static final String TAG = "GainPlayer";

    // Frames written per chunk (~23 ms at 44.1 kHz). Within a chunk the gains
    // glide from the previous to the current value, so a gain change, the
    // start and the stop do not click.
    private static final int CHUNK_FRAMES = 1024;

    // A sound source: mono samples in -1.0..1.0, endless (a file loops).
    interface Source {
        int sampleRate();

        // Fills out[0..count) with the next samples.
        void read(float[] out, int count) throws Exception;

        void release();
    }

    private final Source source;
    private final AudioTrack track;
    private final Thread thread;

    // Id of the output device the sound is routed to, or -1 for the default
    // output.
    final int deviceId;

    private volatile float leftGain;
    private volatile float rightGain;
    private volatile boolean stopRequested = false;

    // Starts playing [source] at once. With a [device] the sound is routed to
    // it; Android otherwise falls back to the default output, so the caller
    // stops the player when that device disconnects.
    GainPlayer(Source source, float leftGain, float rightGain, AudioDeviceInfo device) {
        this.source = source;
        this.leftGain = leftGain;
        this.rightGain = rightGain;

        final int sampleRate = source.sampleRate();
        final int minBufSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT);

        track = new AudioTrack.Builder()
                .setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build())
                .setAudioFormat(new AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build())
                .setBufferSizeInBytes(Math.max(minBufSize, CHUNK_FRAMES * 4) * 2)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build();

        if (device != null) track.setPreferredDevice(device);
        deviceId = device != null ? device.getId() : -1;

        track.play();
        thread = new Thread(this::run, "GainPlayer");
        thread.start();
    }

    void setGains(float left, float right) {
        leftGain = left;
        rightGain = right;
    }

    // Fades out (one chunk) and releases everything.
    void stop() {
        stopRequested = true;
        try { thread.join(500); } catch (InterruptedException ignored) {}
        try {
            track.stop();
            track.release();
        } catch (Exception ignored) {}
        // NOTE: Only release the source once the thread no longer reads it.
        if (!thread.isAlive()) source.release();
    }

    private void run() {
        final float[] mono = new float[CHUNK_FRAMES];
        final short[] stereo = new short[CHUNK_FRAMES * 2];
        // Start silent: the first chunk fades in.
        float left = 0f;
        float right = 0f;

        try {
            while (true) {
                final boolean stopping = stopRequested;
                // The last chunk fades out to silence.
                final float targetLeft  = stopping ? 0f : leftGain;
                final float targetRight = stopping ? 0f : rightGain;

                source.read(mono, CHUNK_FRAMES);
                for (int i = 0; i < CHUNK_FRAMES; i++) {
                    final float t = (i + 1) / (float) CHUNK_FRAMES;
                    final float sample = mono[i] * Short.MAX_VALUE;
                    stereo[i * 2]     = (short) (sample * (left  + (targetLeft  - left)  * t)); // L
                    stereo[i * 2 + 1] = (short) (sample * (right + (targetRight - right) * t)); // R
                }
                left = targetLeft;
                right = targetRight;

                track.write(stereo, 0, stereo.length);
                if (stopping) break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Playback failed", e);
        }
    }

    // ── Sources ──────────────────────────────────────────────────────────────

    // 440 Hz sine wave (A4), the calibration test tone.
    static final class Sine implements Source {
        private static final int SAMPLE_RATE = 44100;
        private static final double STEP = 2.0 * Math.PI * 440 / SAMPLE_RATE;
        private double phase = 0;

        @Override
        public int sampleRate() {
            return SAMPLE_RATE;
        }

        @Override
        public void read(float[] out, int count) {
            for (int i = 0; i < count; i++) {
                out[i] = (float) Math.sin(phase);
                phase += STEP;
                if (phase > 2.0 * Math.PI) phase -= 2.0 * Math.PI;
            }
        }

        @Override
        public void release() {}
    }

    // An audio file (e.g. MP3), decoded with MediaCodec, mixed down to mono
    // and played in a loop.
    //
    // NOTE: Mixed down on purpose: the calibration compares the two ears, so
    // both get the same signal and only the gain differs. MediaPlayer's
    // balance (used by audioplayers before) did not change a mono file.
    static final class AudioFile implements Source {
        // Give up if the decoder delivers nothing for this many attempts
        // (10 ms each), instead of blocking the playback thread forever.
        private static final int MAX_EMPTY_ATTEMPTS = 500;

        private final MediaExtractor extractor = new MediaExtractor();
        private final MediaCodec codec;
        private final int sampleRate;
        private int channels;

        private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        private short[] pending = new short[0];
        private int pendingPos = 0;
        private int pendingLen = 0;
        private boolean inputDone = false;

        AudioFile(String path) throws Exception {
            extractor.setDataSource(path);
            MediaFormat format = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                final MediaFormat f = extractor.getTrackFormat(i);
                final String mime = f.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    extractor.selectTrack(i);
                    format = f;
                    break;
                }
            }
            if (format == null) {
                extractor.release();
                throw new IllegalArgumentException("No audio track in " + path);
            }

            sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE);
            channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME));
            codec.configure(format, null, null, 0);
            codec.start();
        }

        @Override
        public int sampleRate() {
            return sampleRate;
        }

        @Override
        public void read(float[] out, int count) {
            int filled = 0;
            int emptyAttempts = 0;
            while (filled < count) {
                if (pendingPos < pendingLen) {
                    while (filled < count && pendingPos + channels <= pendingLen) {
                        float sum = 0f;
                        for (int c = 0; c < channels; c++) sum += pending[pendingPos + c];
                        out[filled++] = sum / channels / 32768f;
                        pendingPos += channels;
                    }
                    if (pendingPos + channels > pendingLen) pendingPos = pendingLen;
                    emptyAttempts = 0;
                    continue;
                }
                if (!decode() && ++emptyAttempts > MAX_EMPTY_ATTEMPTS) {
                    throw new IllegalStateException("Decoder delivers no audio");
                }
            }
        }

        // Feeds the decoder and takes one output buffer into [pending].
        // Returns whether samples were added.
        private boolean decode() {
            if (!inputDone) {
                final int in = codec.dequeueInputBuffer(10_000);
                if (in >= 0) {
                    final ByteBuffer buffer = codec.getInputBuffer(in);
                    final int size = buffer != null ? extractor.readSampleData(buffer, 0) : -1;
                    if (size < 0) {
                        codec.queueInputBuffer(in, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                        inputDone = true;
                    } else {
                        codec.queueInputBuffer(in, 0, size, extractor.getSampleTime(), 0);
                        extractor.advance();
                    }
                }
            }

            final int out = codec.dequeueOutputBuffer(info, 10_000);
            if (out == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                channels = Math.max(1, codec.getOutputFormat()
                        .getInteger(MediaFormat.KEY_CHANNEL_COUNT));
                return false;
            }
            if (out < 0) return false;

            boolean added = false;
            final ByteBuffer buffer = codec.getOutputBuffer(out);
            if (buffer != null && info.size > 0) {
                buffer.position(info.offset);
                buffer.limit(info.offset + info.size);
                final ShortBuffer samples =
                        buffer.slice().order(ByteOrder.nativeOrder()).asShortBuffer();
                final int length = samples.remaining();
                if (pending.length < length) pending = new short[length];
                samples.get(pending, 0, length);
                pendingPos = 0;
                pendingLen = length;
                added = length > 0;
            }
            codec.releaseOutputBuffer(out, false);

            if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                // Loop: start the file again.
                extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
                codec.flush();
                inputDone = false;
            }
            return added;
        }

        @Override
        public void release() {
            try { codec.stop(); } catch (Exception ignored) {}
            codec.release();
            extractor.release();
        }
    }
}
