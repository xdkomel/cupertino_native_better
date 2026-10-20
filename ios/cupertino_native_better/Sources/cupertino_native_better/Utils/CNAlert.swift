import Flutter
import UIKit

/// The system's own confirmation (UIAlertController) for Flutter: a centered
/// alert, an action sheet from the bottom, or one coming out of a button.
/// Answers true when the destructive action was chosen.
final class CNAlert {
  static func setup(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "cn_alert", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard call.method == "confirm" else {
        result(FlutterMethodNotImplemented)
        return
      }
      present(args, result: result)
    }
  }

  private static func present(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let host = topController() else { result(false); return }
    let style = args["style"] as? String ?? "alert"
    let alert = UIAlertController(
      title: args["title"] as? String,
      message: args["message"] as? String,
      preferredStyle: style == "alert" ? .alert : .actionSheet
    )
    alert.addAction(UIAlertAction(title: args["confirm"] as? String, style: .destructive) { _ in
      result(true)
    })
    alert.addAction(UIAlertAction(title: args["cancel"] as? String, style: .cancel) { _ in
      result(false)
    })
    if style == "anchored", let rect = args["anchor"] as? [String: NSNumber],
       let popover = alert.popoverPresentationController {
      popover.sourceView = host.view
      popover.sourceRect = CGRect(
        x: rect["x"]?.doubleValue ?? 0,
        y: rect["y"]?.doubleValue ?? 0,
        width: rect["w"]?.doubleValue ?? 1,
        height: rect["h"]?.doubleValue ?? 1
      )
    }
    host.present(alert, animated: true)
  }

  private static func topController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
