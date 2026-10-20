import CoreHaptics
import Flutter
import UIKit

/// Plays haptic patterns sent from Flutter with Core Haptics: a list of
/// transient taps and continuous hums, each with a time, an intensity and a
/// sharpness (Opengater addition).
final class CNHaptics {
  private static var engine: CHHapticEngine?
  private static var player: CHHapticPatternPlayer?

  static func setup(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cn_haptics", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "play":
        let events = (call.arguments as? [String: Any])?["events"] as? [[String: Any]] ?? []
        play(events)
        result(nil)
      case "stop":
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func readyEngine() -> CHHapticEngine? {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
    if let engine = engine { return engine }
    guard let created = try? CHHapticEngine() else { return nil }
    created.isAutoShutdownEnabled = true
    created.resetHandler = { try? created.start() }
    engine = created
    return created
  }

  private static func play(_ raw: [[String: Any]]) {
    guard let engine = readyEngine() else { return }
    let events: [CHHapticEvent] = raw.map { e in
      let time = (e["t"] as? NSNumber)?.doubleValue ?? 0
      let params = [
        CHHapticEventParameter(
          parameterID: .hapticIntensity,
          value: (e["i"] as? NSNumber)?.floatValue ?? 0.5),
        CHHapticEventParameter(
          parameterID: .hapticSharpness,
          value: (e["s"] as? NSNumber)?.floatValue ?? 0.5),
      ]
      if let duration = (e["d"] as? NSNumber)?.doubleValue {
        return CHHapticEvent(
          eventType: .hapticContinuous, parameters: params,
          relativeTime: time, duration: duration)
      }
      return CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: time)
    }
    // A hum may fade out over its length.
    var curves: [CHHapticParameterCurve] = []
    for e in raw {
      guard let fade = e["fade"] as? [NSNumber], fade.count == 2,
            let duration = (e["d"] as? NSNumber)?.doubleValue else { continue }
      let start = (e["t"] as? NSNumber)?.doubleValue ?? 0
      curves.append(CHHapticParameterCurve(
        parameterID: .hapticIntensityControl,
        controlPoints: [
          .init(relativeTime: start, value: fade[0].floatValue),
          .init(relativeTime: start + duration, value: fade[1].floatValue),
        ],
        relativeTime: 0))
    }
    do {
      try engine.start()
      let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
      try? player?.stop(atTime: CHHapticTimeImmediate)
      let next = try engine.makePlayer(with: pattern)
      try next.start(atTime: CHHapticTimeImmediate)
      player = next
    } catch {
      NSLog("[CNHaptics] \(error)")
    }
  }
}
