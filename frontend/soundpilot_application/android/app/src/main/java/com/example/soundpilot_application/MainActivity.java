// File: android/app/src/main/java/com/example/soundpilot_application/MainActivity.java

package com.example.soundpilot_application;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "com.soundpilot/audio_devices";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {

            if (call.method.equals("getConnectedOutputDevices")) {
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
                    result.error(
                            "AUDIO_DEVICE_ERROR",
                            "Fehler beim Abrufen der Audiogeräte: " + e.getMessage(),
                            null
                    );
                }

            } else {
                result.notImplemented();
            }
        });
    }

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