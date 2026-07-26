import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupAudioChannel(engine: engineBridge.engine!)
  }

  private func setupAudioChannel(engine: FlutterEngine) {
    let channel = FlutterMethodChannel(
      name: "com.wolow/audio_output",
      binaryMessenger: engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }

      switch call.method {
      case "getDevices":
        self.getAudioDevices(result: result)

      case "getActiveDevice":
        self.getActiveDevice(result: result)

      case "setActiveDevice":
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
          return
        }
        self.setActiveDevice(deviceId: deviceId, result: result)

      case "getVolume":
        self.getVolume(result: result)

      case "setVolume":
        guard let args = call.arguments as? [String: Any],
              let level = args["level"] as? Int else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing level", details: nil))
          return
        }
        self.setVolume(level: level, result: result)

      case "toggleMute":
        self.toggleMute(result: result)

      case "isMuted":
        self.isMuted(result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func getAudioDevices(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    var devices: [[String: Any]] = []

    do {
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
    } catch {
      // Category may already be set
    }

    // Current route
    let currentRoute = session.currentRoute
    let currentOutputs = currentRoute.outputs

    for output in currentOutputs {
      let port = output.portType
      let name = output.portName
      let uid = output.uid

      let type: String
      switch port {
      case .builtInSpeaker:
        type = "speaker"
      case .builtInReceiver:
        type = "speaker"
      case .headphones:
        type = "headphones"
      case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
        type = "bluetooth"
      case .airPlay:
        type = "bluetooth"
      case .usbAudio:
        type = "usb"
      case .HDMI:
        type = "hdmi"
      default:
        type = "speaker"
      }

      let displayName = name.isEmpty ? defaultName(for: type) : name

      devices.append([
        "id": uid,
        "name": displayName,
        "type": type,
        "isCurrentlySelected": true  // All outputs in current route are active
      ])
    }

    // If no outputs found, add default speaker
    if devices.isEmpty {
      devices.append([
        "id": "built-in-speaker",
        "name": "Phone Speaker",
        "type": "speaker",
        "isCurrentlySelected": true
      ])
    }

    result(devices)
  }

  private func getActiveDevice(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    let currentRoute = session.currentRoute

    if let output = currentRoute.outputs.first {
      let port = output.portType
      let type: String
      switch port {
      case .builtInSpeaker, .builtInReceiver: type = "speaker"
      case .headphones: type = "headphones"
      case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .airPlay: type = "bluetooth"
      case .usbAudio: type = "usb"
      case .HDMI: type = "hdmi"
      default: type = "speaker"
      }

      result([
        "id": output.uid,
        "name": output.portName.isEmpty ? defaultName(for: type) : output.portName,
        "type": type,
        "isCurrentlySelected": true
      ])
    } else {
      result([
        "id": "built-in-speaker",
        "name": "Phone Speaker",
        "type": "speaker",
        "isCurrentlySelected": true
      ])
    }
  }

  private func setActiveDevice(deviceId: String, result: @escaping FlutterResult) {
    // iOS doesn't support programmatic audio route switching via API.
    // The recommended approach is to show AVRoutePickerView.
    // For now, we return success and the user can switch via Control Center.
    result(false)
  }

  private func getVolume(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    let volume = Int(session.outputVolume * 100)
    result(volume)
  }

  private func setVolume(level: Int, result: @escaping FlutterResult) {
    // iOS volume is controlled via MPVolumeView or system volume
    // Direct API access is restricted by Apple
    result(false)
  }

  private func toggleMute(result: @escaping FlutterResult) {
    // iOS doesn't provide a direct mute API for app audio
    result(false)
  }

  private func isMuted(result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    result(session.isOtherAudioPlaying)
  }

  private func defaultName(for type: String) -> String {
    switch type {
    case "headphones": return "Wired Headphones"
    case "bluetooth": return "Bluetooth Audio"
    case "usb": return "USB Audio"
    case "hdmi": return "HDMI Output"
    default: return "Phone Speaker"
    }
  }
}
