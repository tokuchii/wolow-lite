package com.wolow.wolow_lite

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wolow/audio_output"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleMethod(call, result) }
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        when (call.method) {
            "getDevices" -> {
                val devices = mutableListOf<Map<String, Any>>()
                val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

                for (device in audioDevices) {
                    val type = when (device.type) {
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
                        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "headphones"
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "headphones"
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetooth"
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
                        AudioDeviceInfo.TYPE_USB_DEVICE -> "usb"
                        AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
                        AudioDeviceInfo.TYPE_HDMI -> "hdmi"
                        AudioDeviceInfo.TYPE_HDMI_ARC -> "hdmi"
                        AudioDeviceInfo.TYPE_HDMI_EARC -> "hdmi"
                        else -> "speaker"
                    }

                    // Skip HDMI if no product name (ghost devices)
                    val productName = device.productName?.toString() ?: ""
                    if (productName.isEmpty() && type == "hdmi") continue

                    val name = if (productName.isNotEmpty()) productName
                    else when (type) {
                        "headphones" -> "Wired Headphones"
                        "bluetooth" -> "Bluetooth Audio"
                        "usb" -> "USB Audio"
                        "hdmi" -> "HDMI Output"
                        else -> "Speaker"
                    }

                    val isSelected = audioManager.isSpeakerphoneOn &&
                            type == "speaker" ||
                            !audioManager.isSpeakerphoneOn && type != "speaker"

                    devices.add(mapOf(
                        "id" to device.id.toString(),
                        "name" to name,
                        "type" to type,
                        "isCurrentlySelected" to (device.id == getDefaultOutputId(audioManager))
                    ))
                }

                // Always include built-in speaker if not already listed
                if (devices.none { it["type"] == "speaker" }) {
                    devices.add(0, mapOf(
                        "id" to "0",
                        "name" to "Phone Speaker",
                        "type" to "speaker",
                        "isCurrentlySelected" to true
                    ))
                }

                result.success(devices)
            }

            "getActiveDevice" -> {
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val activeId = getDefaultOutputId(audioManager)
                val activeDevice = devices.find { it.id == activeId }

                if (activeDevice != null) {
                    val type = mapDeviceType(activeDevice.type)
                    val name = activeDevice.productName?.toString()?.ifEmpty {
                        defaultDeviceName(type)
                    } ?: defaultDeviceName(type)

                    result.success(mapOf(
                        "id" to activeDevice.id.toString(),
                        "name" to name,
                        "type" to type,
                        "isCurrentlySelected" to true
                    ))
                } else {
                    result.success(mapOf(
                        "id" to "0",
                        "name" to "Phone Speaker",
                        "type" to "speaker",
                        "isCurrentlySelected" to true
                    ))
                }
            }

            "setActiveDevice" -> {
                // On Android, app-level routing is limited.
                // For speaker vs earpiece, we can use setSpeakerphoneOn.
                // For Bluetooth/USB, the user needs to connect the device.
                val deviceId = call.argument<Int>("deviceId") ?: 0
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                val targetDevice = devices.find { it.id == deviceId }

                if (targetDevice != null) {
                    when (targetDevice.type) {
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> {
                            audioManager.isSpeakerphoneOn = true
                            result.success(true)
                        }
                        AudioDeviceInfo.TYPE_WIRED_HEADSET,
                        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
                            audioManager.isSpeakerphoneOn = false
                            result.success(true)
                        }
                        else -> {
                            audioManager.isSpeakerphoneOn = false
                            result.success(true)
                        }
                    }
                } else {
                    result.success(false)
                }
            }

            "getVolume" -> {
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                val percent = (curVol * 100) / maxVol
                result.success(percent)
            }

            "setVolume" -> {
                val level = call.argument<Int>("level") ?: 50
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                val vol = (level * maxVol) / 100
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, vol, 0)
                result.success(true)
            }

            "toggleMute" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val isMuted = audioManager.isStreamMute(AudioManager.STREAM_MUSIC)
                    audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        if (isMuted) AudioManager.ADJUST_UNMUTE else AudioManager.ADJUST_MUTE,
                        0
                    )
                    result.success(!isMuted)
                } else {
                    result.success(false)
                }
            }

            "isMuted" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    result.success(audioManager.isStreamMute(AudioManager.STREAM_MUSIC))
                } else {
                    result.success(false)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun getDefaultOutputId(audioManager: AudioManager): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val commDevice = audioManager.communicationDevice
            if (commDevice != null) return commDevice.id
        }
        // Fallback: check if speaker is on
        return if (audioManager.isSpeakerphoneOn) 0 else -1
    }

    private fun mapDeviceType(androidType: Int): String {
        return when (androidType) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "headphones"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
            AudioDeviceInfo.TYPE_HDMI,
            AudioDeviceInfo.TYPE_HDMI_ARC,
            AudioDeviceInfo.TYPE_HDMI_EARC -> "hdmi"
            else -> "speaker"
        }
    }

    private fun defaultDeviceName(type: String): String {
        return when (type) {
            "headphones" -> "Wired Headphones"
            "bluetooth" -> "Bluetooth Audio"
            "usb" -> "USB Audio"
            "hdmi" -> "HDMI Output"
            else -> "Phone Speaker"
        }
    }
}
