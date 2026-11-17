// File: android/app/src/main/java/com/example/soundpilot_application/GainMixer.java
//
// The arithmetic of the player: which gain every single sample is multiplied
// by. The glide between two gain pairs, the cues of a recording, and how long
// is left until everything written has been played.
//
// Deliberately free of Android classes, so JUnit can run it on the JVM
// (android/app/src/test, run by ./gradlew test in CI). GainPlayer keeps the
// AudioTrack, the decoder and the thread around it; everything that can be
// wrong by a sample or a frame lives here.

package com.example.soundpilot_application;

final class GainMixer {

    // One step of an exercise: from [atMs] into the recording, glide to these
    // gains over [rampMs].
    //
    // NOTE: Counted in frames *written*, not in wall time. The gains are
    // applied to the samples, so the panning and the words travel through the
    // same buffer and the same Bluetooth link and reach the ear together,
    // whatever that link's latency is. A timer on the Dart side cannot do
    // that: it runs ahead of the sound by however much is buffered.
    static final class Cue {
        final int atMs;
        final float left;
        final float right;
        final int rampMs;

        Cue(int atMs, float left, float right, int rampMs) {
            this.atMs = atMs;
            this.left = left;
            this.right = right;
            this.rampMs = rampMs;
        }

        long frame(int sampleRate) {
            return (long) atMs * sampleRate / 1000;
        }
    }

    private final int sampleRate;
    private final int chunkFrames;

    // The directions of a recording, in order; empty for a test sound.
    private final Cue[] cues;

    // The gains as they are applied right now. A new glide starts from these,
    // so one that interrupts another carries on from where it was instead of
    // jumping.
    private float currentLeft;
    private float currentRight;

    private float fromLeft;
    private float fromRight;
    private float toLeft;
    private float toRight;
    private int rampFrames = 1;
    private int rampPosition = 1;

    private long framesWritten;
    private int cueIndex;
    private boolean fadingOut;

    GainMixer(int sampleRate, int chunkFrames, float leftGain, float rightGain,
              Cue[] cues) {
        this.sampleRate = sampleRate;
        this.chunkFrames = chunkFrames;
        this.cues = cues != null ? cues : new Cue[0];
        // Starts silent, so the first chunk fades in instead of clicking.
        this.currentLeft = 0f;
        this.currentRight = 0f;
        glideTo(leftGain, rightGain, 0);
    }

    float currentLeft() {
        return currentLeft;
    }

    float currentRight() {
        return currentRight;
    }

    long framesWritten() {
        return framesWritten;
    }

    // Glides to the new gains over rampMs, starting from wherever the gains
    // are at this moment. 0 or less takes one chunk (~23 ms at 44.1 kHz),
    // which is what the calibration wheel wants: the tone has to follow the
    // finger, not drift after it.
    void glideTo(float left, float right, int rampMs) {
        fromLeft = currentLeft;
        fromRight = currentRight;
        toLeft = left;
        toRight = right;
        rampFrames = rampFrames(rampMs);
        rampPosition = 0;
    }

    // Fades to silence over one chunk and stops taking cues: the next mix is
    // the last one.
    void fadeOut() {
        fadingOut = true;
        glideTo(0f, 0f, 0);
    }

    // Mixes [count] mono samples (−1.0…1.0) into [stereo] as interleaved
    // 16 bit, applying every cue whose frame has come and the running glide.
    //
    // [count] may be shorter than a chunk at the end of a recording; the rest
    // of the chunk is silence, which the fade-out of [fadeOut] then lands on.
    void mix(float[] mono, int count, short[] stereo) {
        if (!fadingOut) takeDueCues();

        for (int i = 0; i < chunkFrames; i++) {
            final float eased = eased(rampPosition, rampFrames);
            currentLeft = fromLeft + (toLeft - fromLeft) * eased;
            currentRight = fromRight + (toRight - fromRight) * eased;

            final float sample = (i < count ? mono[i] : 0f) * Short.MAX_VALUE;
            stereo[i * 2] = (short) (sample * currentLeft);      // L
            stereo[i * 2 + 1] = (short) (sample * currentRight); // R

            if (rampPosition < rampFrames) rampPosition++;
        }

        framesWritten += chunkFrames;
    }

    // Starts the glide of every cue that is due. With more than one in the
    // same chunk the last one wins, and a cue beats a gain that was sent from
    // Dart meanwhile: while a recording has cues, they own the direction.
    private void takeDueCues() {
        while (cueIndex < cues.length
                && cues[cueIndex].frame(sampleRate) <= framesWritten) {
            final Cue cue = cues[cueIndex];
            glideTo(cue.left, cue.right, cue.rampMs);
            cueIndex++;
        }
    }

    private int rampFrames(int rampMs) {
        if (rampMs <= 0) return chunkFrames;
        final long frames = (long) rampMs * sampleRate / 1000;
        return (int) Math.max(1, Math.min(Integer.MAX_VALUE, frames));
    }

    // Eased position of a ramp, 0.0 at its start and 1.0 at its end.
    //
    // NOTE: Smoothstep, not a straight line: the movement sets in softly and
    // arrives softly instead of sliding mechanically from one side to the
    // other.
    static float eased(int position, int frames) {
        if (frames <= 0 || position >= frames) return 1f;
        final float t = position / (float) frames;
        return t * t * (3f - 2f * t);
    }

    // Milliseconds until the frame at [totalFrames] has been played, given a
    // timestamp saying that [framePosition] frames have been presented.
    static long millisUntilPlayedOut(long totalFrames, long framePosition,
                                     int sampleRate) {
        if (sampleRate <= 0) return 0;
        final long left = totalFrames - framePosition;
        return left <= 0 ? 0 : left * 1000 / sampleRate;
    }
}
