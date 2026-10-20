import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let probeChannelName = "fuel_metrics/headunit_probe"
  private let telemetryChannelName = "fuel_metrics/headunit_telemetry"

  private var eventSink: FlutterEventSink?
  private var isCarPlayAttached = false
  private var simulatedStatus = "STATUS_SUCCESS"
  private var simulatedFuelPercent = 82.0
  private var simulatedOdometerMeters: Int64 = 31200000

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupChannels(messenger: messenger)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupChannels(messenger: engineBridge.engine.binaryMessenger)
  }

  private func setupChannels(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: probeChannelName, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "getAttachmentStatus":
        result([
          "isAttached": self.isCarPlayAttached,
          "connectionType": self.isCarPlayAttached ? "PROJECTION" : "NONE"
        ])
      case "probeCapabilities":
        let isNative = self.simulatedStatus == "STATUS_SUCCESS"
        result([
          "isAttached": self.isCarPlayAttached,
          "status": self.simulatedStatus,
          "fuelSupported": isNative,
          "odometerSupported": isNative,
          "currentFuelPercent": isNative ? self.simulatedFuelPercent : nil,
          "currentOdometerMeters": isNative ? self.simulatedOdometerMeters : nil
        ])
      case "simulateAttachment":
        let args = call.arguments as? [String: Any]
        self.isCarPlayAttached = args?["isAttached"] as? Bool ?? false
        self.simulatedStatus = args?["status"] as? String ?? "STATUS_SUCCESS"
        if let f = args?["fuelPercent"] as? Double { self.simulatedFuelPercent = f }
        if let o = args?["odometerMeters"] as? Int64 { self.simulatedOdometerMeters = o }
        
        if self.isCarPlayAttached {
          self.eventSink?([
            "event": "ATTACHED",
            "status": self.simulatedStatus,
            "fuelPercent": self.simulatedFuelPercent,
            "odometerMeters": self.simulatedOdometerMeters
          ])
        } else {
          self.eventSink?([
            "event": "DETACHED"
          ])
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(name: telemetryChannelName, binaryMessenger: messenger)
    eventChannel.setStreamHandler(StreamHandler(onListen: { [weak self] sink in
      self?.eventSink = sink
      if let self = self, self.isCarPlayAttached {
        sink([
          "event": "CURRENT_STATE",
          "status": self.simulatedStatus,
          "fuelPercent": self.simulatedFuelPercent,
          "odometerMeters": self.simulatedOdometerMeters
        ])
      }
    }, onCancel: { [weak self] in
      self?.eventSink = nil
    }))
  }
}

private class StreamHandler: NSObject, FlutterStreamHandler {
  let onListenBlock: (FlutterEventSink?) -> Void
  let onCancelBlock: () -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void, onCancel: @escaping () -> Void) {
    self.onListenBlock = onListen
    self.onCancelBlock = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenBlock(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelBlock()
    return nil
  }
}
