// File: android/app/src/main/java/com/example/soundpilot_application/GainPlayer.java
//
// Plays a mono sound source on both ears with separate left and right gains,
// optionally on one output device. Used for the calibration test tone and the
// exercise recordings (see MainActivity). The two gains carry the whole
// left/right image, the direction of a sound included (SpatialAudioEngine on
// the Dart side), and a change of direction is glided per sample.
//
// This file is the Android half: the AudioTrack, the decoder and the playback
// thread. Which gain each sample is multiplied by is GainMixer's, which has no
// Android classes in it and is therefore covered by JUnit tests.

package com.example.soundpilot_application;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioTimestamp;
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

    // Added to the fallback wait for the end of a recording (see
    // awaitPlayedOut). getPlaybackHeadPosition only counts what the audio HAL
    // has consumed, so on a device that reports no timestamp the Bluetooth
    // link still holds a few hundred milliseconds that nothing can measure.
    private static final int FALLBACK_LATENCY_MS = 300;

    // A sound source: mono samples in -1.0..1.0.
    interface Source {
        int sampleRate();

        // Fills out[0..count) with the next samples and returns how many it
        // could deliver. Fewer than count means the source has ended; one
        // that loops never ends.
        int read(float[] out, int count) throws Exception;

        void release();
    }

    // Gains to glide to, set by setGains and taken by the playback thread at
    // the start of its next chunk; null while there is nothing new.
    private static final class Target {
        final float left;
        final float right;
        final int rampMs;

        Target(float left, float right, int rampMs) {
            this.left = left;
            this.right = right;
            this.rampMs = rampMs;
        }
    }

    private final Source source;
    private final AudioTrack track;
    private final Thread thread;
    private final int sampleRate;

    // Which gain every sample is multiplied by (see GainMixer).
    private final GainMixer mixer;

    // How much audio the AudioTrack buffer holds, in milliseconds.
    private final int bufferMs;

    // Run once the recording has been played to its end *and* heard; null if
    // nobody wants to know.
    private final Runnable onEnded;

    // Id of the output device the sound is routed to, or -1 for the default
    // output.
    final int deviceId;

    private volatile Target pending;
    private volatile boolean stopRequested = false;

    // Starts playing [source] at once. With a [device] the sound is routed to
    // it; Android otherwise falls back to the default output, so the caller
    // stops the player when that device disconnects.
    GainPlayer(Source source, float leftGain, float rightGain, AudioDeviceInfo device,
               GainMixer.Cue[] cues, Runnable onEnded) {
        this.source = source;
        this.onEnded = onEnded;

        final int sampleRate = source.sampleRate();
        this.sampleRate = sampleRate;
        // The mixer starts silent, so its first chunk fades in.
        this.mixer =
                new GainMixer(sampleRate, CHUNK_FRAMES, leftGain, rightGain, cues);
        final int minBufSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT);
        final int bufferBytes = Math.max(minBufSize, CHUNK_FRAMES * 4) * 2;
        // 4 bytes per frame (stereo, 16 bit).
        this.bufferMs = (int) ((long) (bufferBytes / 4) * 1000 / sampleRate);

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
                .setBufferSizeInBytes(bufferBytes)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build();

        if (device != null) track.setPreferredDevice(device);
        deviceId = device != null ? device.getId() : -1;

        track.play();
        thread = new Thread(this::run, "GainPlayer");
        thread.start();
    }

    // Glides to the new gains over rampMs, eased in and out (GainMixer).
    // 0 or less takes one chunk (~23 ms), which is what the calibration wheel
    // wants: the tone has to follow the finger, not drift after it.
    //
    // NOTE: The glide belongs here, per sample, and not in a series of gain
    // values sent from Dart. Stepped gains are audible as a faint crackle
    // ("zipper noise"), and a Dart timer cannot hit a sample boundary anyway.
    // Dart says where to go and in how long; the rest happens in this thread.
    void setGains(float left, float right, int rampMs) {
        pending = new Target(left, right, rampMs);
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

        boolean ended = false;

        try {
            while (true) {
                final int read = source.read(mono, CHUNK_FRAMES);
                // Fewer samples than asked for: the recording has ended, and
                // the mixer pads the chunk with silence while it fades out.
                if (read < CHUNK_FRAMES) ended = true;

                final boolean stopping = stopRequested || ended;
                if (stopping) {
                    mixer.fadeOut();
                } else {
                    final Target next = pending;
                    if (next != null) {
                        pending = null;
                        mixer.glideTo(next.left, next.right, next.rampMs);
                    }
                }

                mixer.mix(mono, Math.max(read, 0), stereo);
                track.write(stereo, 0, stereo.length);
                if (stopping) break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Playback failed", e);
        }

        // The recording ran out on its own, so whoever asked for it is told —
        // but only once it has really been heard.
        //
        // NOTE: Reported after the wait gives up as well (it has a timeout),
        // because a screen that never hears the end would keep saying that the
        // exercise is running. Only a stop() cancels the report, and the Dart
        // side takes the first of event and fallback timer, so the two cannot
        // end the exercise twice.
        if (ended && !stopRequested && onEnded != null) {
            awaitPlayedOut(mixer.framesWritten());
            if (!stopRequested) onEnded.run();
        }
    }

    // Waits until everything written has been played. At the moment the last
    // chunk is written, the AudioTrack buffer still holds ~80-180 ms and the
    // output itself more — on Bluetooth another 150-300 ms.
    //
    // NOTE: getTimestamp's nanoTime is when a frame is *presented*, so it
    // covers what the device still has in the pipe. getPlaybackHeadPosition
    // only counts what the HAL consumed, which is why the fallback waits one
    // buffer length on top of it.
    private void awaitPlayedOut(long totalFrames) {
        final long giveUpAt = System.currentTimeMillis() + 10_000;
        try {
            final AudioTimestamp stamp = new AudioTimestamp();
            while (!stopRequested && System.currentTimeMillis() < giveUpAt) {
                if (track.getTimestamp(stamp) && stamp.framePosition > 0) {
                    final long left = GainMixer.millisUntilPlayedOut(
                            totalFrames, stamp.framePosition, sampleRate);
                    if (left <= 0) return;
                    if (!sleepSliced(left + 10)) return;
                    continue;
                }
                if (track.getPlaybackHeadPosition() >= totalFrames) {
                    sleepSliced(bufferMs + FALLBACK_LATENCY_MS);
                    return;
                }
                if (!sleepSliced(20)) return;
            }
        } catch (Exception ignored) {
            // The track was released while waiting, i.e. the screen was left.
        }
    }

    // Sleeps in slices, so a stop() is noticed inside one of them instead of
    // after the whole wait. False if a stop came.
    private boolean sleepSliced(long millis) throws InterruptedException {
        final long until = System.currentTimeMillis() + millis;
        while (!stopRequested) {
            final long left = until - System.currentTimeMillis();
            if (left <= 0) return true;
            Thread.sleep(Math.min(25, left));
        }
        return false;
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
