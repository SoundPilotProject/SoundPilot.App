// File: android/app/src/main/java/com/example/soundpilot_application/MainActivity.java
//
// Native Android side of the audio/Bluetooth channels used by
// AudioDeviceService (lib/core/services/audio_device_service.dart).

package com.example.soundpilot_application;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothClass;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.soundpilot/audio_devices";

    // Stream of the current output device list, sent again on every change.
    private static final String EVENT_CHANNEL = "com.soundpilot/audio_device_events";

    private static final int BLUETOOTH_PERMISSION_REQUEST = 4201;
    private static final String PREFS = "soundpilot_native";
    private static final String PREF_BT_PERMISSION_ASKED = "bluetoothPermissionAsked";

    // Test tone state
    private AudioTrack audioTrack = null;
    private Thread toneThread = null;
    private volatile boolean isPlayingTone = false;

    // Set to end the tone; the tone thread fades out and then stops.
    private volatile boolean stopToneRequested = false;

    // Gains (0.0–1.0) the tone glides to; changed by setTestToneGain while it
    // plays.
    private volatile float toneLeftGain = 0f;
    private volatile float toneRightGain = 0f;

    // Id of the output device the test tone is routed to, or -1 if the tone
    // plays on the default output.
    private int toneDeviceId = -1;

    // Device events
    private AudioManager audioManager;
    private AudioDeviceCallback deviceCallback;
    private EventChannel.EventSink deviceEventSink = null;

    // Result of a running permission request, answered in
    // onRequestPermissionsResult.
    private MethodChannel.Result pendingPermissionResult = null;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        audioManager = (AudioManager) getSystemService(Context.AUDIO_SERVICE);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {

            switch (call.method) {

                case "getConnectedOutputDevices":
                    handleGetDevices(result);
                    break;

                case "playTestTone":
                    Integer deviceId = call.argument("deviceId");
                    handlePlayTone(gainArgument(call.argument("leftGain")),
                            gainArgument(call.argument("rightGain")),
                            deviceId, result);
                    break;

                case "setTestToneGain":
                    toneLeftGain  = gainArgument(call.argument("leftGain"));
                    toneRightGain = gainArgument(call.argument("rightGain"));
                    result.success(null);
                    break;

                case "stopTestTone":
                    handleStopTone(result);
                    break;

                case "getBluetoothPermissionStatus":
                    result.success(bluetoothPermissionStatus());
                    break;

                case "requestBluetoothPermission":
                    handleRequestBluetoothPermission(result);
                    break;

                case "getBluetoothState":
                    result.success(bluetoothState());
                    break;

                case "getPairedAudioDevices":
                    handleGetPairedAudioDevices(result);
                    break;

                case "openBluetoothSettings":
                    result.success(openSettings(new Intent(Settings.ACTION_BLUETOOTH_SETTINGS)));
                    break;

                case "openAppSettings":
                    result.success(openSettings(new Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", getPackageName(), null))));
                    break;

                default:
                    result.notImplemented();
            }
        });

        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EVENT_CHANNEL
        ).setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                deviceEventSink = events;
                events.success(currentOutputDevices());
            }

            @Override
            public void onCancel(Object arguments) {
                deviceEventSink = null;
            }
        });

        registerDeviceCallback();
    }

    // ── Get connected audio output devices ───────────────────────────────────

    private void handleGetDevices(MethodChannel.Result result) {
        try {
            result.success(currentOutputDevices());
        } catch (Exception e) {
            result.error("AUDIO_DEVICE_ERROR",
                    "Fehler beim Abrufen der Audiogeräte: " + e.getMessage(), null);
        }
    }

    private List<Map<String, Object>> currentOutputDevices() {
        AudioDeviceInfo[] devices =
                audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);

        List<Map<String, Object>> deviceList = new ArrayList<>();
        for (AudioDeviceInfo device : devices) {
            deviceList.add(deviceToMap(device));
        }
        return deviceList;
    }

    // NOTE: "address" is the Bluetooth address (BD_ADDR) for Bluetooth
    // devices and an empty string below Android 9, where getAddress() does
    // not exist. Without BLUETOOTH_CONNECT, Android 12+ may report it
    // partly anonymised (to be checked on a real phone).
    private Map<String, Object> deviceToMap(AudioDeviceInfo device) {
        Map<String, Object> map = new HashMap<>();
        map.put("id",          device.getId());
        map.put("productName", device.getProductName().toString());
        map.put("type",        deviceTypeName(device.getType()));
        map.put("typeCode",    device.getType());
        map.put("isBluetooth", isBluetoothType(device.getType()));
        map.put("address",
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ? device.getAddress() : "");
        return map;
    }

    // ── Device events ────────────────────────────────────────────────────────
    //
    // The callback stays registered while the activity lives (not only while
    // Dart listens), so the test tone is always stopped when its headphones
    // go away. Otherwise Android would move the tone to the phone speaker.

    private void registerDeviceCallback() {
        if (deviceCallback != null) return;

        deviceCallback = new AudioDeviceCallback() {
            @Override
            public void onAudioDevicesAdded(AudioDeviceInfo[] addedDevices) {
                sendDeviceList();
            }

            @Override
            public void onAudioDevicesRemoved(AudioDeviceInfo[] removedDevices) {
                for (AudioDeviceInfo device : removedDevices) {
                    if (isPlayingTone && device.getId() == toneDeviceId) {
                        stopToneInternal();
                    }
                }
                sendDeviceList();
            }
        };
        audioManager.registerAudioDeviceCallback(
                deviceCallback, new Handler(Looper.getMainLooper()));
    }

    private void sendDeviceList() {
        if (deviceEventSink != null) {
            deviceEventSink.success(currentOutputDevices());
        }
    }

    // ── Play stereo test tone ─────────────────────────────────────────────────
    //
    // Generates a 440 Hz sine wave with separate left and right gains
    // (0.0–1.0, already on a hearing curve, see wheelToGain in Dart).
    //
    // The tone is written in short chunks (CHUNK_FRAMES, ~23 ms). Within a
    // chunk the gains glide from the previous to the current value, so a gain
    // change (setTestToneGain), the start and the stop do not click.
    //
    // With a deviceId the tone is routed to that output (e.g. the headphones
    // being calibrated) and fails with DEVICE_NOT_CONNECTED if it is not
    // connected, instead of falling back to the speaker. Without a deviceId
    // it plays on the default output.

    private static final int CHUNK_FRAMES = 1024;

    // Gain from a channel argument (a Dart double), limited to 0.0–1.0.
    private static float gainArgument(Object value) {
        float gain = value instanceof Number ? ((Number) value).floatValue() : 0.5f;
        return Math.max(0f, Math.min(1f, gain));
    }

    private void handlePlayTone(float leftGain, float rightGain, Integer deviceId,
                                MethodChannel.Result result) {
        // Stop any currently playing tone first
        stopToneInternal();

        AudioDeviceInfo target = null;
        if (deviceId != null) {
            target = findOutputDevice(deviceId);
            if (target == null) {
                result.error("DEVICE_NOT_CONNECTED",
                        "Die Kopfhörer sind nicht verbunden.", null);
                return;
            }
        }

        toneLeftGain  = leftGain;
        toneRightGain = rightGain;
        stopToneRequested = false;

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
                    .setBufferSizeInBytes(Math.max(minBufSize, CHUNK_FRAMES * 4) * 2)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build();

            if (target != null) {
                audioTrack.setPreferredDevice(target);
                toneDeviceId = target.getId();
            }

            audioTrack.play();
            isPlayingTone = true;

            final AudioTrack track = audioTrack;

            toneThread = new Thread(() -> {
                final short[] buffer = new short[CHUNK_FRAMES * 2]; // stereo
                final double step = 2.0 * Math.PI * frequency / sampleRate;
                double phase = 0;
                // Start silent: the first chunk fades in.
                float left = 0f;
                float right = 0f;

                while (true) {
                    final boolean stopping = stopToneRequested;
                    // The last chunk fades out to silence.
                    final float targetLeft  = stopping ? 0f : toneLeftGain;
                    final float targetRight = stopping ? 0f : toneRightGain;

                    for (int i = 0; i < CHUNK_FRAMES; i++) {
                        final float t = (i + 1) / (float) CHUNK_FRAMES;
                        final double sample = Math.sin(phase) * Short.MAX_VALUE;
                        buffer[i * 2]     = (short) (sample * (left  + (targetLeft  - left)  * t)); // L
                        buffer[i * 2 + 1] = (short) (sample * (right + (targetRight - right) * t)); // R
                        phase += step;
                        if (phase > 2.0 * Math.PI) phase -= 2.0 * Math.PI;
                    }
                    left = targetLeft;
                    right = targetRight;

                    track.write(buffer, 0, buffer.length);
                    if (stopping) break;
                }
            });

            toneThread.start();
            result.success(null);

        } catch (Exception e) {
            stopToneInternal();
            result.error("TONE_ERROR",
                    "Fehler beim Abspielen des Testtons: " + e.getMessage(), null);
        }
    }

    private AudioDeviceInfo findOutputDevice(int id) {
        for (AudioDeviceInfo device :
                audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            if (device.getId() == id) return device;
        }
        return null;
    }

    // ── Stop tone ─────────────────────────────────────────────────────────────

    private void handleStopTone(MethodChannel.Result result) {
        stopToneInternal();
        result.success(null);
    }

    // Fades the tone out (one chunk) and releases it.
    private void stopToneInternal() {
        stopToneRequested = true;
        isPlayingTone = false;
        toneDeviceId = -1;

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
        if (deviceCallback != null) {
            audioManager.unregisterAudioDeviceCallback(deviceCallback);
            deviceCallback = null;
        }
        deviceEventSink = null;
        if (pendingPermissionResult != null) {
            pendingPermissionResult.success(bluetoothPermissionStatus());
            pendingPermissionResult = null;
        }
        super.onDestroy();
    }

    // ── Bluetooth permission ─────────────────────────────────────────────────
    //
    // Statuses (strings, read by Dart): "granted", "denied",
    // "permanentlyDenied". Below Android 12 there is no runtime permission,
    // so it is always "granted".
    //
    // NOTE: Android does not report "permanently denied" directly. It is
    // derived: the permission was asked before, is not granted, and Android
    // no longer wants a rationale (shouldShowRequestPermissionRationale).
    // Android then does not show the dialog again; only the app settings
    // can grant it.

    private boolean needsRuntimeBluetoothPermission() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
    }

    private boolean hasBluetoothPermission() {
        return !needsRuntimeBluetoothPermission()
                || checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                        == PackageManager.PERMISSION_GRANTED;
    }

    private String bluetoothPermissionStatus() {
        if (hasBluetoothPermission()) return "granted";

        boolean askedBefore = getSharedPreferences(PREFS, MODE_PRIVATE)
                .getBoolean(PREF_BT_PERMISSION_ASKED, false);
        if (askedBefore
                && !shouldShowRequestPermissionRationale(Manifest.permission.BLUETOOTH_CONNECT)) {
            return "permanentlyDenied";
        }
        return "denied";
    }

    private void handleRequestBluetoothPermission(MethodChannel.Result result) {
        if (hasBluetoothPermission()) {
            result.success("granted");
            return;
        }
        if (pendingPermissionResult != null) {
            result.error("REQUEST_RUNNING",
                    "Die Berechtigung wird bereits abgefragt.", null);
            return;
        }

        pendingPermissionResult = result;
        SharedPreferences.Editor editor =
                getSharedPreferences(PREFS, MODE_PRIVATE).edit();
        editor.putBoolean(PREF_BT_PERMISSION_ASKED, true);
        editor.apply();

        requestPermissions(
                new String[]{Manifest.permission.BLUETOOTH_CONNECT},
                BLUETOOTH_PERMISSION_REQUEST);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           @NonNull String[] permissions,
                                           @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != BLUETOOTH_PERMISSION_REQUEST || pendingPermissionResult == null) {
            return;
        }

        MethodChannel.Result result = pendingPermissionResult;
        pendingPermissionResult = null;
        // Re-read instead of using grantResults: it also covers a cancelled
        // request (empty grantResults) and the permanently denied case.
        result.success(bluetoothPermissionStatus());
    }

    // ── Bluetooth state ──────────────────────────────────────────────────────

    // "on", "off", or "unavailable" if the device has no Bluetooth (e.g. an
    // emulator without virtual Bluetooth).
    private String bluetoothState() {
        BluetoothAdapter adapter = bluetoothAdapter();
        if (adapter == null) return "unavailable";
        try {
            return adapter.isEnabled() ? "on" : "off";
        } catch (SecurityException e) {
            return "unavailable";
        }
    }

    private BluetoothAdapter bluetoothAdapter() {
        BluetoothManager manager =
                (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        return manager != null ? manager.getAdapter() : null;
    }

    // ── Paired audio devices ─────────────────────────────────────────────────
    //
    // Headphones paired in the Android settings, connected or not
    // (Bluetooth class AUDIO_VIDEO). Needs the Bluetooth permission; an empty
    // list if Bluetooth is off or missing.

    private void handleGetPairedAudioDevices(MethodChannel.Result result) {
        if (!hasBluetoothPermission()) {
            result.error("PERMISSION_DENIED",
                    "Die Bluetooth-Berechtigung fehlt.", null);
            return;
        }

        List<Map<String, Object>> deviceList = new ArrayList<>();
        BluetoothAdapter adapter = bluetoothAdapter();
        if (adapter == null) {
            result.success(deviceList);
            return;
        }

        try {
            Set<BluetoothDevice> bonded = adapter.getBondedDevices();
            if (bonded != null) {
                for (BluetoothDevice device : bonded) {
                    BluetoothClass btClass = device.getBluetoothClass();
                    if (btClass == null
                            || btClass.getMajorDeviceClass()
                                    != BluetoothClass.Device.Major.AUDIO_VIDEO) {
                        continue;
                    }
                    Map<String, Object> map = new HashMap<>();
                    String name = device.getName();
                    map.put("name",    name != null ? name : "");
                    map.put("address", device.getAddress());
                    deviceList.add(map);
                }
            }
            result.success(deviceList);
        } catch (SecurityException e) {
            result.error("PERMISSION_DENIED",
                    "Die Bluetooth-Berechtigung fehlt.", null);
        }
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    // Opens a system settings page; false if the phone has no such page.
    private boolean openSettings(Intent intent) {
        try {
            startActivity(intent);
            return true;
        } catch (ActivityNotFoundException e) {
            return false;
        }
    }

    // ── Device type names ─────────────────────────────────────────────────────

    private boolean isBluetoothType(int type) {
        return type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                || type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                || type == AudioDeviceInfo.TYPE_BLE_HEADSET;
    }

    private String deviceTypeName(int type) {
        switch (type) {
            case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:   return "Bluetooth (A2DP)";
            case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:    return "Bluetooth (SCO/Headset)";
            case AudioDeviceInfo.TYPE_BLE_HEADSET:      return "Bluetooth (LE Audio)";
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
