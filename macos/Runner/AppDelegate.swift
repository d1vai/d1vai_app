import Cocoa
import FlutterMacOS

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
class AppDelegate: FlutterAppDelegate {
  private let openChannelName = "ai.d1v.d1vai/open"
  private let windowChannelName = "ai.d1v.d1vai/window"
  private let oauthCallbackChannelName = "ai.d1v.d1vaiapp/oauth_callback"
  private let oauthCallbackControlChannelName = "ai.d1v.d1vaiapp/oauth_callback_control"
  private var openChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?
  private var oauthCallbackChannel: FlutterEventChannel?
  private var oauthCallbackControlChannel: FlutterMethodChannel?
  private var pendingImportPaths: [String] = []
  private let oauthCallbackStreamHandler = OAuthCallbackStreamHandler()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    configureOpenChannelIfPossible()
    configureOAuthChannelsIfPossible()
    flushPendingImportPaths()
  }

  func configureOpenChannel(binaryMessenger: FlutterBinaryMessenger) {
    openChannel = FlutterMethodChannel(
      name: openChannelName,
      binaryMessenger: binaryMessenger
    )
    windowChannel = FlutterMethodChannel(
      name: windowChannelName,
      binaryMessenger: binaryMessenger
    )
    windowChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window_unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "beginWindowDrag":
        self.beginWindowDrag(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    NSLog("[d1vai-drop] appDelegate configured open channel")
    flushPendingImportPaths()
  }

  func configureOAuthChannels(binaryMessenger: FlutterBinaryMessenger) {
    if oauthCallbackChannel == nil {
      oauthCallbackChannel = FlutterEventChannel(
        name: oauthCallbackChannelName,
        binaryMessenger: binaryMessenger
      )
      oauthCallbackChannel?.setStreamHandler(oauthCallbackStreamHandler)
    }

    if oauthCallbackControlChannel == nil {
      oauthCallbackControlChannel = FlutterMethodChannel(
        name: oauthCallbackControlChannelName,
        binaryMessenger: binaryMessenger
      )
      oauthCallbackControlChannel?.setMethodCallHandler { [weak self] call, result in
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
  }

  private func beginWindowDrag(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let window = self.mainFlutterWindow ?? NSApp.mainWindow else {
        result(FlutterError(code: "window_unavailable", message: "Main window not found", details: nil))
        return
      }
      guard let event = NSApp.currentEvent else {
        result(FlutterError(code: "event_unavailable", message: "No current mouse event", details: nil))
        return
      }
      window.performDrag(with: event)
      result(nil)
    }
  }

  private func configureOpenChannelIfPossible() {
    if openChannel != nil, oauthCallbackChannel != nil, oauthCallbackControlChannel != nil {
      return
    }
    guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      NSLog("[d1vai-drop] appDelegate configure skipped missing flutterViewController")
      return
    }
    configureOpenChannel(binaryMessenger: flutterViewController.engine.binaryMessenger)
    configureOAuthChannels(binaryMessenger: flutterViewController.engine.binaryMessenger)
  }

  private func configureOAuthChannelsIfPossible() {
    if oauthCallbackChannel != nil, oauthCallbackControlChannel != nil {
      return
    }
    guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    configureOAuthChannels(binaryMessenger: flutterViewController.engine.binaryMessenger)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      queueImportPathIfNeeded(path: filename)
    }
    flushPendingImportPaths()
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      if url.scheme?.lowercased() == "d1vai" {
        configureOAuthChannelsIfPossible()
        oauthCallbackStreamHandler.handle(url: url)
      }
    }
  }

  func handleDroppedPaths(_ paths: [String]) {
    NSLog("[d1vai-drop] appDelegate handleDroppedPaths paths=%@", paths.joined(separator: " | "))
    for path in paths {
      queueImportPathIfNeeded(path: path)
    }
    flushPendingImportPaths()
  }

  private func queueImportPathIfNeeded(path: String) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
      NSLog("[d1vai-drop] appDelegate queue skipped missing path=%@", path)
      return
    }
    if isDirectory.boolValue || FileManager.default.isReadableFile(atPath: path) {
      NSLog("[d1vai-drop] appDelegate queue accepted path=%@ isDirectory=%@", path, isDirectory.boolValue ? "true" : "false")
      pendingImportPaths.append(path)
    } else {
      NSLog("[d1vai-drop] appDelegate queue rejected unreadable path=%@", path)
    }
  }

  private func flushPendingImportPaths() {
    if openChannel == nil {
      configureOpenChannelIfPossible()
    }
    guard let channel = openChannel, !pendingImportPaths.isEmpty else {
      if pendingImportPaths.isEmpty {
        NSLog("[d1vai-drop] appDelegate flush skipped empty queue")
      } else {
        NSLog("[d1vai-drop] appDelegate flush skipped missing channel")
      }
      return
    }

    let paths = pendingImportPaths
    pendingImportPaths.removeAll()
    NSLog("[d1vai-drop] appDelegate flush sending count=%ld", paths.count)
    for path in paths {
      NSLog("[d1vai-drop] appDelegate invoke openImportPath path=%@", path)
      channel.invokeMethod("openImportPath", arguments: path)
    }
  }
}
