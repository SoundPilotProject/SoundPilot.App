// File: android/app/src/main/java/com/example/soundpilot_application/MainActivity.java

package com.example.soundpilot_application;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.soundpilot/audio_devices";

    // Test tone state
    private AudioTrack audioTrack = null;
    private Thread toneThread = null;
    private volatile boolean isPlayingTone = false;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {

            switch (call.method) {

                case "getConnectedOutputDevices":
                    handleGetDevices(result);
                    break;

                case "playTestTone":
                    int leftVol  = call.argument("leftVolume")  != null ? (int) call.argument("leftVolume")  : 50;
                    int rightVol = call.argument("rightVolume") != null ? (int) call.argument("rightVolume") : 50;
                    handlePlayTone(leftVol, rightVol, result);
                    break;

                case "stopTestTone":
                    handleStopTone(result);
                    break;

                default:
                    result.notImplemented();
            }
        });
    }

    // ── Get connected audio output devices ───────────────────────────────────

    private void handleGetDevices(MethodChannel.Result result) {
        try {
            AudioManager audioManager =
                    (AudioManager) getSystemService(Context.AUDIO_SERVICE);

            AudioDeviceInfo[] devices =
                    audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);

            List<Map<String, Object>> deviceList = new ArrayList<>();
            for (AudioDeviceInfo device : devices) {
                Map<String, Object> map = new HashMap<>();
                map.put("id",          device.getId());
                map.put("productName", device.getProductName().toString());
                map.put("type",        deviceTypeName(device.getType()));
                deviceList.add(map);
            }
            result.success(deviceList);

        } catch (Exception e) {
            result.error("AUDIO_DEVICE_ERROR",
                    "Fehler beim Abrufen der Audiogeräte: " + e.getMessage(), null);
        }
    }

    // ── Play stereo test tone ─────────────────────────────────────────────────
    //
    // Generates a 440 Hz sine wave. Left and right gains are derived from
    // the calibration values (1–100  →  0.01–1.0).

    private void handlePlayTone(int leftVolume, int rightVolume,
                                MethodChannel.Result result) {
        // Stop any currently playing tone first
        stopToneInternal();

        final float leftGain  = leftVolume  / 100.0f;
        final float rightGain = rightVolume / 100.0f;

        final int sampleRate = 44100;
        final int frequency  = 440; // Hz – standard A4 tone

        final int minBufSize = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_STEREO,
                AudioFormat.ENCODING_PCM_16BIT);

        try {
            audioTrack = new AudioTrack.Builder()
                    .setAudioAttributes(new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build())
                    .setAudioFormat(new AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                            .build())
                    .setBufferSizeInBytes(minBufSize * 2)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build();

            audioTrack.play();
            isPlayingTone = true;

            final AudioTrack track = audioTrack;

            toneThread = new Thread(() -> {
                // Generate one full second of the sine wave as a looping buffer
                int bufSamples = sampleRate; // 1 second per loop
                short[] buffer = new short[bufSamples * 2]; // *2 for stereo

                for (int i = 0; i < bufSamples; i++) {
                    double angle = 2.0 * Math.PI * frequency * i / sampleRate;
                    short sample = (short) (Math.sin(angle) * Short.MAX_VALUE);
                    buffer[i * 2]     = (short) (sample * leftGain);  // L
                    buffer[i * 2 + 1] = (short) (sample * rightGain); // R
                }

                while (isPlayingTone) {
                    track.write(buffer, 0, buffer.length);
                }
            });

            toneThread.start();
            result.success(null);

        } catch (Exception e) {
            result.error("TONE_ERROR",
                    "Fehler beim Abspielen des Testtons: " + e.getMessage(), null);
        }
    }

    // ── Stop tone ─────────────────────────────────────────────────────────────

    private void handleStopTone(MethodChannel.Result result) {
        stopToneInternal();
        result.success(null);
    }

    private void stopToneInternal() {
        isPlayingTone = false;

        if (toneThread != null) {
            try { toneThread.join(500); } catch (InterruptedException ignored) {}
            toneThread = null;
        }

        if (audioTrack != null) {
            try {
                audioTrack.stop();
                audioTrack.release();
            } catch (Exception ignored) {}
            audioTrack = null;
        }
    }

    @Override
    protected void onDestroy() {
        stopToneInternal();
        super.onDestroy();
    }

    // ── Device type names ─────────────────────────────────────────────────────

    private String deviceTypeName(int type) {
        switch (type) {
            case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:   return "Bluetooth (A2DP)";
            case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:    return "Bluetooth (SCO/Headset)";
            case AudioDeviceInfo.TYPE_WIRED_HEADSET:    return "Kabelgebundenes Headset";
            case AudioDeviceInfo.TYPE_WIRED_HEADPHONES: return "Kabelgebundene Kopfhörer";
            case AudioDeviceInfo.TYPE_USB_HEADSET:      return "USB-Headset";
            case AudioDeviceInfo.TYPE_USB_DEVICE:       return "USB-Audiogerät";
            case AudioDeviceInfo.TYPE_BUILTIN_SPEAKER:  return "Lautsprecher";
            case AudioDeviceInfo.TYPE_BUILTIN_EARPIECE: return "Ohrhörer (intern)";
            case AudioDeviceInfo.TYPE_HDMI:             return "HDMI";
            case AudioDeviceInfo.TYPE_LINE_ANALOG:      return "Klinke (analog)";
            case AudioDeviceInfo.TYPE_LINE_DIGITAL:     return "Klinke (digital)";
            case AudioDeviceInfo.TYPE_AUX_LINE:         return "AUX";
            default:                                    return "Unbekannt (" + type + ")";
        }
    }
}