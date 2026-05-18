import Flutter
import UIKit

private final class OAuthCallbackStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var pendingCallbackURL: String?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    if let pendingCallbackURL {
      events(pendingCallbackURL)
      self.pendingCallbackURL = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func handle(url: URL) {
    let value = url.absoluteString
    if let eventSink {
      eventSink(value)
      return
    }
    pendingCallbackURL = value
  }

  func takePendingCallback() -> String? {
    let value = pendingCallbackURL
    pendingCallbackURL = nil
    return value
  }

  func clearPendingCallback() {
    pendingCallbackURL = nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let oauthCallbackStreamHandler = OAuthCallbackStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let eventChannel = FlutterEventChannel(
        name: "ai.d1v.d1vaiapp/oauth_callback",
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(oauthCallbackStreamHandler)

      let methodChannel = FlutterMethodChannel(
        name: "ai.d1v.d1vaiapp/oauth_callback_control",
        binaryMessenger: controller.binaryMessenger
      )
      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterMethodNotImplemented)
          return
        }

        switch call.method {
        case "takePending":
          result(self.oauthCallbackStreamHandler.takePendingCallback())
        case "clearPending":
          self.oauthCallbackStreamHandler.clearPendingCallback()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.scheme?.lowercased() == "d1vai" {
      oauthCallbackStreamHandler.handle(url: url)
      return true
    }

    return super.application(app, open: url, options: options)
  }
}
