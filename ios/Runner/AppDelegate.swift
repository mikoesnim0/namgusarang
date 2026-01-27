import Flutter
import CoreMotion
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pedometer = CMPedometer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(
        name: "com.doyakmin.hangookji.namgu/steps",
        binaryMessenger: controller.binaryMessenger
      )

      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else { return }
        switch call.method {
        case "isAvailable":
          result(CMPedometer.isStepCountingAvailable())
        case "getPermissionStatus":
          result(self.permissionStatus())
        case "requestPermission":
          self.requestPermission(result: result)
        case "getTodaySteps":
          self.getTodaySteps(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let eventChannel = FlutterEventChannel(
        name: "com.doyakmin.hangookji.namgu/steps_stream",
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(StepsStreamHandler())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func permissionStatus() -> String {
    guard CMPedometer.isStepCountingAvailable() else { return "notSupported" }

    if #available(iOS 11.0, *) {
      switch CMPedometer.authorizationStatus() {
      case .authorized:
        return "granted"
      case .denied:
        return "denied"
      case .restricted:
        return "restricted"
      case .notDetermined:
        return "unknown"
      @unknown default:
        return "unknown"
      }
    }

    return "unknown"
  }

  private func requestPermission(result: @escaping FlutterResult) {
    guard CMPedometer.isStepCountingAvailable() else {
      result(false)
      return
    }

    let startOfDay = Calendar.current.startOfDay(for: Date())
    pedometer.queryPedometerData(from: startOfDay, to: Date()) { _, error in
      DispatchQueue.main.async {
        if error != nil {
          result(false)
        } else {
          result(true)
        }
      }
    }
  }

  private func getTodaySteps(result: @escaping FlutterResult) {
    guard CMPedometer.isStepCountingAvailable() else {
      result(nil)
      return
    }

    let startOfDay = Calendar.current.startOfDay(for: Date())
    pedometer.queryPedometerData(from: startOfDay, to: Date()) { data, _ in
      DispatchQueue.main.async {
        if let steps = data?.numberOfSteps {
          result(steps.intValue)
        } else {
          result(nil)
        }
      }
    }
  }
}
