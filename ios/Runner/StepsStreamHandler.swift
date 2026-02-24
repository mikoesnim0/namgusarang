import CoreMotion
import Flutter
import Foundation

final class StepsStreamHandler: NSObject, FlutterStreamHandler {
  private let pedometer = CMPedometer()
  private var eventSink: FlutterEventSink?
  private var midnightTimer: Timer?
  private var streamStartDay: Date?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard CMPedometer.isStepCountingAvailable() else {
      events(FlutterError(code: "not_supported", message: "Step counting is not available", details: nil))
      return nil
    }

    self.eventSink = events
    startPedometerStream()
    scheduleMidnightTimer()

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopPedometerStream()
    cancelMidnightTimer()
    eventSink = nil
    return nil
  }

  private func startPedometerStream() {
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    streamStartDay = startOfDay

    pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
      guard let self = self else { return }

      DispatchQueue.main.async {
        if let error = error {
          self.eventSink?(FlutterError(code: "pedometer_error", message: error.localizedDescription, details: nil))
          return
        }

        // Check if the day has changed (safety check)
        let currentDay = Calendar.current.startOfDay(for: Date())
        if let streamDay = self.streamStartDay, currentDay != streamDay {
          // Day changed, restart stream
          self.restartPedometerStream()
          return
        }

        if let steps = data?.numberOfSteps {
          self.eventSink?(steps.intValue)
        }
      }
    }
  }

  private func stopPedometerStream() {
    pedometer.stopUpdates()
    streamStartDay = nil
  }

  private func restartPedometerStream() {
    stopPedometerStream()
    startPedometerStream()
    // Reschedule timer for next midnight
    scheduleMidnightTimer()
  }

  private func scheduleMidnightTimer() {
    cancelMidnightTimer()

    let now = Date()
    let calendar = Calendar.current

    // Calculate next midnight
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
      return
    }

    let timeUntilMidnight = tomorrow.timeIntervalSince(now)

    // Schedule timer to fire at midnight
    midnightTimer = Timer.scheduledTimer(withTimeInterval: timeUntilMidnight, repeats: false) { [weak self] _ in
      self?.restartPedometerStream()
    }
  }

  private func cancelMidnightTimer() {
    midnightTimer?.invalidate()
    midnightTimer = nil
  }
}

