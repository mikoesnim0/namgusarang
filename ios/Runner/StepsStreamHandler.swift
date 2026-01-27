import CoreMotion
import Flutter
import Foundation

final class StepsStreamHandler: NSObject, FlutterStreamHandler {
  private let pedometer = CMPedometer()

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CMPedometer.isStepCountingAvailable() else {
      events(FlutterError(code: "not_supported", message: "Step counting is not available", details: nil))
      return nil
    }

    let startOfDay = Calendar.current.startOfDay(for: Date())
    pedometer.startUpdates(from: startOfDay) { data, error in
      DispatchQueue.main.async {
        if let error = error {
          events(FlutterError(code: "pedometer_error", message: error.localizedDescription, details: nil))
          return
        }
        if let steps = data?.numberOfSteps {
          events(steps.intValue)
        }
      }
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    pedometer.stopUpdates()
    return nil
  }
}

