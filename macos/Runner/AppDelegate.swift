import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openChannelName = "ai.d1v.d1vai/open"
  private var openChannel: FlutterMethodChannel?
  private var pendingImportPaths: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    configureOpenChannelIfPossible()
    flushPendingImportPaths()
  }

  func configureOpenChannel(binaryMessenger: FlutterBinaryMessenger) {
    openChannel = FlutterMethodChannel(
      name: openChannelName,
      binaryMessenger: binaryMessenger
    )
    NSLog("[d1vai-drop] appDelegate configured open channel")
    flushPendingImportPaths()
  }

  private func configureOpenChannelIfPossible() {
    if openChannel != nil {
      return
    }
    guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      NSLog("[d1vai-drop] appDelegate configure skipped missing flutterViewController")
      return
    }
    configureOpenChannel(binaryMessenger: flutterViewController.engine.binaryMessenger)
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
