import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let openChannelName = "ai.d1v.d1vai/open"
  private var openChannel: FlutterMethodChannel?
  private var pendingDirectoryPaths: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    guard let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: openChannelName,
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    openChannel = channel

    flushPendingDirectories()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      queueDirectoryIfNeeded(path: filename)
    }
    flushPendingDirectories()
    sender.reply(toOpenOrPrint: .success)
  }

  func handleDroppedPaths(_ paths: [String]) {
    for path in paths {
      queueDirectoryIfNeeded(path: path)
    }
    flushPendingDirectories()
  }

  private func queueDirectoryIfNeeded(path: String) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return
    }
    pendingDirectoryPaths.append(path)
  }

  private func flushPendingDirectories() {
    guard let channel = openChannel, !pendingDirectoryPaths.isEmpty else {
      return
    }

    let paths = pendingDirectoryPaths
    pendingDirectoryPaths.removeAll()
    for path in paths {
      channel.invokeMethod("openDirectory", arguments: path)
    }
  }
}
