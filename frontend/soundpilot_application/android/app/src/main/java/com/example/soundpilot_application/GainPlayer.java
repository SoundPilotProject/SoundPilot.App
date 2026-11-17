// File: android/app/src/main/java/com/example/soundpilot_application/GainPlayer.java
//
// Plays a mono sound source on both ears with separate left and right gains,
// optionally on one output device. Used for the calibration test tone and the
// exercise recordings (see MainActivity). The two gains carry the whole
// left/right image, the direction of a sound included (SpatialAudioEngine on
// the Dart side), and a change of direction is glided here, per sample.

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

    // A sound source: mono samples in -1.0..1.0.
    interface Source {
        int sampleRate();

        // Fills out[0..count) with the next samples and returns how many it
        // could deliver. Fewer than count means the source has ended; one
        // that loops never ends.
        int read(float[] out, int count) throws Exception;

        void release();
    }

    // A pair of gains to glide to, and how many frames that glide takes.
    private static final class Ramp {
        final float left;
        final float right;
        final int frames;

        Ramp(float left, float right, int frames) {
            this.left = left;
            this.right = right;
            this.frames = Math.max(1, frames);
        }
    }

    private final Source source;
    private final AudioTrack track;
    private final Thread thread;
    private final int sampleRate;

    // Id of the output device the sound is routed to, or -1 for the default
    // output.
    final int deviceId;

    // The ramp to start next, set by setGains and taken by the playback thread
    // at the start of its next chunk; null while there is nothing new.
    private volatile Ramp pending;
    private volatile boolean stopRequested = false;

    // Starts playing [source] at once. With a [device] the sound is routed to
    // it; Android otherwise falls back to the default output, so the caller
    // stops the player when that device disconnects.
    GainPlayer(Source source, float leftGain, float rightGain, AudioDeviceInfo device) {
        this.source = source;
        // The first ramp fades in from silence over one chunk, so the start
        // does not click.
        this.pending = new Ramp(leftGain, rightGain, CHUNK_FRAMES);

        final int sampleRate = source.sampleRate();
        this.sampleRate = sampleRate;
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

    // Glides to the new gains over rampMs, eased in and out (see run()).
    // 0 or less takes one chunk (~23 ms), which is what the calibration wheel
    // wants: the tone has to follow the finger, not drift after it.
    //
    // NOTE: The glide belongs here, per sample, and not in a series of gain
    // values sent from Dart. Stepped gains are audible as a faint crackle
    // ("zipper noise"), and a Dart timer cannot hit a sample boundary anyway.
    // Dart says where to go and in how long; the rest happens in this thread.
    void setGains(float left, float right, int rampMs) {
        final int frames = rampMs > 0
                ? (int) Math.min(Integer.MAX_VALUE, (long) rampMs * sampleRate / 1000)
                : CHUNK_FRAMES;
        pending = new Ramp(left, right, frames);
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

    // Eased position of a ramp, 0.0 at its start and 1.0 at its end.
    //
    // NOTE: Smoothstep, not a straight line: the movement sets in softly and
    // arrives softly, instead of sliding mechanically from one side to the
    // other.
    private static float eased(int position, int frames) {
        if (position >= frames) return 1f;
        final float t = position / (float) frames;
        return t * t * (3f - 2f * t);
    }

    private void run() {
        final float[] mono = new float[CHUNK_FRAMES];
        final short[] stereo = new short[CHUNK_FRAMES * 2];

        // The gains as they are applied right now; a new ramp starts from
        // these, so an interrupted glide carries on from where it was instead
        // of jumping.
        float currentLeft = 0f;
        float currentRight = 0f;

        float fromLeft = 0f;
        float fromRight = 0f;
        float toLeft = 0f;
        float toRight = 0f;
        int rampFrames = 1;
        int rampPosition = 1;

        boolean ended = false;

        try {
            while (true) {
                int read = source.read(mono, CHUNK_FRAMES);
                if (read < CHUNK_FRAMES) {
                    // The source has ended: silence for the rest of the chunk,
                    // and this chunk fades out.
                    java.util.Arrays.fill(mono, Math.max(read, 0), CHUNK_FRAMES, 0f);
                    ended = true;
                }

                final boolean stopping = stopRequested || ended;
                if (stopping) {
                    // The last chunk fades out to silence.
                    fromLeft = currentLeft;
                    fromRight = currentRight;
                    toLeft = 0f;
                    toRight = 0f;
                    rampFrames = CHUNK_FRAMES;
                    rampPosition = 0;
                } else {
                    final Ramp next = pending;
                    if (next != null) {
                        pending = null;
                        fromLeft = currentLeft;
                        fromRight = currentRight;
                        toLeft = next.left;
                        toRight = next.right;
                        rampFrames = next.frames;
                        rampPosition = 0;
                    }
                }

                for (int i = 0; i < CHUNK_FRAMES; i++) {
                    final float e = eased(rampPosition, rampFrames);
                    currentLeft = fromLeft + (toLeft - fromLeft) * e;
                    currentRight = fromRight + (toRight - fromRight) * e;

                    final float sample = mono[i] * Short.MAX_VALUE;
                    stereo[i * 2]     = (short) (sample * currentLeft);  // L
                    stereo[i * 2 + 1] = (short) (sample * currentRight); // R

                    if (rampPosition < rampFrames) rampPosition++;
                }

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
        public int read(float[] out, int count) {
            for (int i = 0; i < count; i++) {
                out[i] = (float) Math.sin(phase);
                phase += STEP;
                if (phase > 2.0 * Math.PI) phase -= 2.0 * Math.PI;
            }
            return count;
        }

        @Override
        public void release() {}
    }

    // An audio file (e.g. MP3), decoded with MediaCodec, mixed down to mono
    // and played once or in a loop.
    //
    // NOTE: A guided exercise must not loop: its recording ends with a closing
    // sentence, and starting over would talk through it. A test sound loops,
    // because it is listened to for as long as the user wants.
    //
    // NOTE: Mixed down on purpose. The calibration compares the two ears, so
    // both get the same signal and only the gain differs — and a direction is
    // panned from those gains at playback time (SpatialAudioEngine on the
    // Dart side), which lets one recording be played from every direction
    // where a pre-panned stereo file could only ever be the one it was mixed
    // as. MediaPlayer's balance (used by audioplayers before) did not change
    // a mono file.
    static final class AudioFile implements Source {
        // Give up if the decoder delivers nothing for this many attempts
        // (10 ms each), instead of blocking the playback thread forever.
        private static final int MAX_EMPTY_ATTEMPTS = 500;

        private final boolean loop;
        private final MediaExtractor extractor = new MediaExtractor();
        private final MediaCodec codec;
        private final int sampleRate;
        private int channels;

        // Set once the file has ended and it is not looping.
        private boolean finished = false;

        private final MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        private short[] pending = new short[0];
        private int pendingPos = 0;
        private int pendingLen = 0;
        private boolean inputDone = false;

        AudioFile(String path, boolean loop) throws Exception {
            this.loop = loop;
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
        public int read(float[] out, int count) {
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
                // Everything decoded is used up: with no loop this is the end
                // of the file, and the player fades out what it has.
                if (finished) return filled;
                if (!decode() && ++emptyAttempts > MAX_EMPTY_ATTEMPTS) {
                    throw new IllegalStateException("Decoder delivers no audio");
                }
            }
            return filled;
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
                if (loop) {
                    // Start the file again.
                    extractor.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
                    codec.flush();
                    inputDone = false;
                } else {
                    finished = true;
                }
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
