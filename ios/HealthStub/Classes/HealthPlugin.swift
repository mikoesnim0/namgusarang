import Flutter

/// Stub HealthPlugin — no-op on iOS.
/// The real health package is only used on Android (Health Connect).
/// This stub satisfies GeneratedPluginRegistrant without linking HealthKit.
public class HealthPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_health",
      binaryMessenger: registrar.messenger()
    )
    let instance = HealthPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
