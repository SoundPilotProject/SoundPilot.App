// File: android/app/src/test/java/com/example/soundpilot_application/GainMixerTest.java
//
// JUnit tests of the player's arithmetic, on the JVM (./gradlew test, run in
// CI). What stays untested in GainPlayer is the writing to AudioTrack and the
// decoder; everything that can be wrong by a sample or a frame is here.

package com.example.soundpilot_application;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class GainMixerTest {

    private static final int SAMPLE_RATE = 44100;
    private static final int CHUNK = 1024;

    // Reading a gain back out of the mixed 16 bit samples costs one step of
    // 1/32767. Where a test reads `currentLeft()` instead, the expected value
    // is exact and the delta is 0.
    private static final float QUANTISATION = 1e-4f;

    /** A chunk of full scale, so every gain shows up in the output. */
    private static float[] fullScale() {
        final float[] mono = new float[CHUNK];
        for (int i = 0; i < CHUNK; i++) mono[i] = 1f;
        return mono;
    }

    private static GainMixer mixer(float left, float right, GainMixer.Cue... cues) {
        return new GainMixer(SAMPLE_RATE, CHUNK, left, right, cues);
    }

    /** Mixes one chunk of full scale and returns the interleaved result. */
    private static short[] mixChunk(GainMixer mixer) {
        final short[] stereo = new short[CHUNK * 2];
        mixer.mix(fullScale(), CHUNK, stereo);
        return stereo;
    }

    /** The left gain of frame [frame] of a mixed chunk. */
    private static float left(short[] stereo, int frame) {
        return stereo[frame * 2] / (float) Short.MAX_VALUE;
    }

    // ── The curve: smoothstep over a fixed duration ──────────────────────────
    //
    // A ramp of n frames is at its target exactly at frame n, which is the
    // first frame after its own window. The frames inside the window end one
    // short of it (position n−1), which is why a value read there needs a
    // tolerance — the curve does not, and a glide is not exponential: it has a
    // duration, not a time constant.

    @Test
    public void easedIsOneOnlyOnceTheRampIsUp() {
        assertEquals(0f, GainMixer.eased(0, 100), 0f);
        assertTrue("one frame short", GainMixer.eased(99, 100) < 1f);
        assertEquals(1f, GainMixer.eased(100, 100), 0f);
        // Past the end it stays there instead of running on.
        assertEquals(1f, GainMixer.eased(500, 100), 0f);
    }

    @Test
    public void easedOnlyEverRisesAndStaysWithinZeroAndOne() {
        float previous = -1f;
        for (int position = 0; position <= 100; position++) {
            final float eased = GainMixer.eased(position, 100);

            assertTrue("eased " + eased, eased >= previous);
            assertTrue("eased " + eased, eased >= 0f && eased <= 1f);
            previous = eased;
        }
    }

    @Test
    public void aRampIsExactlyAtItsTargetWhenItsTimeIsUp() {
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);

        // 100 ms is 4410 frames. Counted from the start of the glide that is
        // frame 314 of the fifth chunk after it.
        mixer.glideTo(0.25f, 0.25f, 100);
        short[] stereo = null;
        for (int chunk = 0; chunk < 5; chunk++) {
            stereo = mixChunk(mixer);
        }

        assertEquals(0.25f, left(stereo, 314), QUANTISATION);
        // Exactly, not nearly: 100 ms is a duration and it is over.
        assertEquals(0.25f, mixer.currentLeft(), 0f);
        assertEquals(0.25f, mixer.currentRight(), 0f);
    }

    @Test
    public void halfWayThroughTheDurationIsHalfWayThere() {
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);

        // A second to the left. Frame 22050 — half of it — is frame 546 of the
        // 22nd chunk after the glide started.
        mixer.glideTo(0f, 1f, 1000);
        short[] stereo = null;
        for (int chunk = 0; chunk < 22; chunk++) {
            stereo = mixChunk(mixer);
        }

        // Smoothstep is symmetric, so half the duration is half the distance.
        // An exponential glide with a time constant of a second would be at
        // 0.61 here, and would still not have arrived after the second.
        assertEquals(0.5f, left(stereo, 546), 2e-3f);
    }

    // ── The glide ────────────────────────────────────────────────────────────

    @Test
    public void startsSilentAndFadesInOverTheFirstChunk() {
        final GainMixer mixer = mixer(1f, 1f);

        final short[] stereo = mixChunk(mixer);

        // A start that jumps straight to the gain clicks, so the first chunk
        // comes up from silence.
        assertEquals(0f, left(stereo, 0), 0f);
        // One frame short of 1.0 at the end of the chunk; there exactly after.
        assertEquals(1f, left(stereo, CHUNK - 1), QUANTISATION);
        mixChunk(mixer);
        assertEquals(1f, mixer.currentLeft(), 0f);
    }

    @Test
    public void aGlideStartedDuringAGlideBeginsAtTheCurrentValue() {
        // A second to the right, interrupted a third of the way in.
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);
        mixer.glideTo(0f, 1f, 1000);
        for (int chunk = 0; chunk < 14; chunk++) {
            mixChunk(mixer);
        }

        final float interrupted = mixer.currentLeft();
        assertTrue("left " + interrupted, interrupted > 0.05f && interrupted < 0.95f);

        mixer.glideTo(1f, 1f, 1000);
        final short[] stereo = mixChunk(mixer);

        // The new glide starts where the old one had got to, not at the value
        // it was once asked for. That is what makes the sound travel through
        // the middle at 71.4/71.8 s of the marching exercise instead of
        // jumping back first.
        assertEquals(interrupted, left(stereo, 0), QUANTISATION);
    }

    @Test
    public void theGainsDoNotJumpBetweenTwoChunks() {
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);
        // Long enough to run over many chunks.
        mixer.glideTo(0f, 1f, 2000);

        // A gain computed once per chunk would step by 1024 frames' worth of
        // the curve here, about 0.017 — 17 times this tolerance.
        final float noStep = 1e-3f;

        float lastOfPreviousChunk = mixer.currentLeft();
        for (int chunk = 0; chunk < 40; chunk++) {
            final short[] stereo = mixChunk(mixer);

            assertEquals("chunk " + chunk, lastOfPreviousChunk, left(stereo, 0),
                    noStep);

            // And inside the chunk nothing jumps either.
            float previous = left(stereo, 0);
            for (int frame = 1; frame < CHUNK; frame++) {
                final float gain = left(stereo, frame);
                assertTrue("step in chunk " + chunk,
                        Math.abs(gain - previous) < noStep);
                previous = gain;
            }

            lastOfPreviousChunk = mixer.currentLeft();
        }
    }

    @Test
    public void aGlideOfZeroIsUpAfterOneChunk() {
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);

        mixer.glideTo(0.25f, 0.75f, 0);
        mixChunk(mixer);
        mixChunk(mixer);

        assertEquals(0.25f, mixer.currentLeft(), 0f);
        assertEquals(0.75f, mixer.currentRight(), 0f);
    }

    // ── The cues ─────────────────────────────────────────────────────────────

    @Test
    public void aCueAppliesAtItsOwnFrameAndNotBefore() {
        // 100 ms is frame 4410, which the chunk starting at 5120 is the first
        // to have passed.
        final GainMixer mixer = mixer(1f, 1f, new GainMixer.Cue(100, 0f, 1f, 0));

        for (int chunk = 0; chunk < 5; chunk++) {
            mixChunk(mixer);
            assertEquals("chunk " + chunk, 1f, mixer.currentLeft(), QUANTISATION);
        }
        assertEquals(5L * CHUNK, mixer.framesWritten());

        // The chunk that takes the cue, and the one that completes its glide.
        mixChunk(mixer);
        mixChunk(mixer);

        assertEquals(0f, mixer.currentLeft(), 0f);
        assertEquals(1f, mixer.currentRight(), 0f);
    }

    @Test
    public void cueFramesFollowTheSampleRate() {
        assertEquals(44100, new GainMixer.Cue(1000, 0f, 0f, 0).frame(44100));
        assertEquals(21400 * 48L, new GainMixer.Cue(21400, 0f, 0f, 0).frame(48000));
        assertEquals(0, new GainMixer.Cue(0, 0f, 0f, 0).frame(44100));
    }

    @Test
    public void severalCuesDueInOneChunkLeaveTheLastOneStanding() {
        // Frames 441, 485 and 529: all inside the first chunk, so all three
        // are due when the second one starts.
        final GainMixer mixer = mixer(
                1f, 1f,
                new GainMixer.Cue(10, 1f, 0f, 0),
                new GainMixer.Cue(11, 0f, 1f, 0),
                new GainMixer.Cue(12, 0.5f, 0.5f, 0));

        mixChunk(mixer);
        mixChunk(mixer);
        mixChunk(mixer);

        assertEquals(0.5f, mixer.currentLeft(), 0f);
        assertEquals(0.5f, mixer.currentRight(), 0f);
    }

    @Test
    public void aCueWinsOverAGainSentMeanwhile() {
        final GainMixer mixer = mixer(1f, 1f, new GainMixer.Cue(0, 0f, 1f, 0));

        // While a recording has cues, they own the direction.
        mixer.glideTo(1f, 0f, 0);
        mixChunk(mixer);
        mixChunk(mixer);

        assertEquals(0f, mixer.currentLeft(), 0f);
        assertEquals(1f, mixer.currentRight(), 0f);
    }

    @Test
    public void aFadeOutTakesNoMoreCues() {
        final GainMixer mixer = mixer(1f, 1f, new GainMixer.Cue(50, 1f, 1f, 0));
        mixChunk(mixer);

        mixer.fadeOut();
        final short[] stereo = mixChunk(mixer);

        // Faded, not cut off: the chunk starts loud and ends silent. Its last
        // frame is the one frame short of 0.0, which the 16 bit sample rounds
        // away — and there is no next chunk, this was the last one.
        assertEquals(1f, left(stereo, 0), QUANTISATION);
        assertEquals(0f, left(stereo, CHUNK - 1), 0f);
        assertTrue(mixer.currentLeft() < QUANTISATION);
        assertTrue(mixer.currentRight() < QUANTISATION);
    }

    @Test
    public void aShortReadIsPaddedWithSilence() {
        final GainMixer mixer = mixer(1f, 1f);
        mixChunk(mixer);

        final short[] stereo = new short[CHUNK * 2];
        mixer.mix(fullScale(), 10, stereo);

        // The ten samples that were there, then silence for the rest.
        assertEquals(1f, left(stereo, 5), QUANTISATION);
        assertEquals(0f, left(stereo, 20), 0f);
        assertEquals(0f, left(stereo, CHUNK - 1), 0f);
    }

    @Test
    public void framesWrittenCountsWholeChunks() {
        final GainMixer mixer = mixer(1f, 1f);

        assertEquals(0, mixer.framesWritten());
        mixChunk(mixer);
        assertEquals(CHUNK, mixer.framesWritten());

        // A short read still writes a whole chunk, padded with silence, so the
        // count stays the frames the track was given.
        mixer.mix(fullScale(), 10, new short[CHUNK * 2]);
        assertEquals(2L * CHUNK, mixer.framesWritten());
    }

    // ── The end of a recording ───────────────────────────────────────────────

    @Test
    public void whatIsLeftToPlayIsTheDistanceToTheLastFrame() {
        // 44100 frames behind at 44.1 kHz is one second of sound still to come.
        assertEquals(1000, GainMixer.millisUntilPlayedOut(88200, 44100, SAMPLE_RATE));
        assertEquals(0, GainMixer.millisUntilPlayedOut(44100, 44100, SAMPLE_RATE));
    }

    @Test
    public void aPositionPastTheEndIsNotNegativeWaiting() {
        assertEquals(0, GainMixer.millisUntilPlayedOut(1000, 5000, SAMPLE_RATE));
        assertEquals(0, GainMixer.millisUntilPlayedOut(5000, 1000, 0));
    }
}
