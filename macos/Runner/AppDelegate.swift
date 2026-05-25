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

private struct MacosOpenRequest {
  let path: String
  let isDirectory: Bool
  let source: String
  let openInNewWindow: Bool

  var windowTitle: String {
    let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    let lastSegment = URL(fileURLWithPath: normalizedPath).lastPathComponent
    let label = lastSegment.isEmpty ? "Local Workspace" : lastSegment
    return "d1v \(label)"
  }

  var flutterArguments: [String: Any] {
    return [
      "path": path,
      "isDirectory": isDirectory,
      "source": source,
      "openInNewWindow": openInNewWindow,
    ]
  }
}

private final class WeakWindowReference {
  weak var window: NSWindow?

  init(window: NSWindow?) {
    self.window = window
  }
}

private struct WorkspaceWindowState {
  let hostIdentifier: String
  let workspacePath: String
  let entryPath: String
  let title: String

  var flutterArguments: [String: Any] {
    return [
      "hostIdentifier": hostIdentifier,
      "workspacePath": workspacePath,
      "entryPath": entryPath,
      "title": title,
    ]
  }
}

private struct PendingRouteRequest {
  let route: String
  let activate: Bool
}

private struct RecentWorkspaceRecord {
  let entryPath: String
  let workspacePath: String
  let title: String
  let seenAt: TimeInterval

  var dictionary: [String: Any] {
    return [
      "entryPath": entryPath,
      "workspacePath": workspacePath,
      "title": title,
      "seenAt": seenAt,
    ]
  }

  var menuTitle: String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedTitle.isEmpty {
      return trimmedTitle
    }
    let lastSegment = URL(fileURLWithPath: workspacePath).lastPathComponent
    if !lastSegment.isEmpty {
      return lastSegment
    }
    return entryPath
  }

  static func from(dictionary: [String: Any]) -> RecentWorkspaceRecord? {
    guard let rawEntryPath = dictionary["entryPath"] as? String else {
      return nil
    }
    let entryPath = rawEntryPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !entryPath.isEmpty else {
      return nil
    }
    let workspacePath =
      (dictionary["workspacePath"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let title =
      (dictionary["title"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let seenAt = dictionary["seenAt"] as? TimeInterval ?? 0
    return RecentWorkspaceRecord(
      entryPath: entryPath,
      workspacePath: workspacePath,
      title: title,
      seenAt: seenAt
    )
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private let openChannelName = "ai.d1v.d1vai/open"
  private let windowChannelName = "ai.d1v.d1vai/window"
  private let oauthCallbackChannelName = "ai.d1v.d1vaiapp/oauth_callback"
  private let oauthCallbackControlChannelName = "ai.d1v.d1vaiapp/oauth_callback_control"
  private let mainHostIdentifier = "main"
  private let recentWorkspaceDefaultsKey = "ai.d1v.d1vai.recent_workspaces"
  private let maxRecentWorkspaceCount = 10

  private var openChannels: [String: FlutterMethodChannel] = [:]
  private var windowChannels: [String: FlutterMethodChannel] = [:]
  private var pendingOpenRequests: [String: [MacosOpenRequest]] = [:]
  private var pendingRouteRequests: [String: [PendingRouteRequest]] = [:]
  private var workspaceWindowControllers: [String: FlutterSecondaryWindowController] = [:]
  private var workspaceWindowStates: [String: WorkspaceWindowState] = [:]
  private var hostWindows: [String: WeakWindowReference] = [:]

  private var oauthCallbackChannel: FlutterEventChannel?
  private var oauthCallbackControlChannel: FlutterMethodChannel?
  private let oauthCallbackStreamHandler = OAuthCallbackStreamHandler()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    configureOAuthChannelsIfPossible()
  }

  func registerMainWindow(
    _ window: NSWindow,
    flutterViewController: FlutterViewController
  ) {
    hostWindows[mainHostIdentifier] = WeakWindowReference(window: window)
    configureChannels(
      hostIdentifier: mainHostIdentifier,
      binaryMessenger: flutterViewController.engine.binaryMessenger,
      windowProvider: { [weak window] in window }
    )
    configureOAuthChannels(binaryMessenger: flutterViewController.engine.binaryMessenger)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    logOpen("building dock menu")
    let menu = NSMenu(title: "Recent Workspaces")
    let recents = loadRecentWorkspaceRecords()
    let recentSubmenu = NSMenu(title: "Recent Workspaces")
    let recentRootItem = NSMenuItem(
      title: "Recent Workspaces",
      action: nil,
      keyEquivalent: ""
    )
    recentRootItem.submenu = recentSubmenu
    menu.addItem(recentRootItem)

    if recents.isEmpty {
      let emptyItem = NSMenuItem(
        title: "No Recent Workspaces",
        action: nil,
        keyEquivalent: ""
      )
      emptyItem.isEnabled = false
      recentSubmenu.addItem(emptyItem)
    } else {
      for record in recents {
        let item = NSMenuItem(
          title: record.menuTitle,
          action: #selector(handleDockRecentWorkspaceSelection(_:)),
          keyEquivalent: ""
        )
        item.target = self
        item.representedObject = record.entryPath as NSString
        recentSubmenu.addItem(item)
      }

      recentSubmenu.addItem(.separator())
      let clearItem = NSMenuItem(
        title: "Clear Recent Workspaces",
        action: #selector(handleDockClearRecentWorkspaces(_:)),
        keyEquivalent: ""
      )
      clearItem.target = self
      recentSubmenu.addItem(clearItem)
    }
    return menu
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    logOpen("application openFiles count=\(filenames.count)")
    handleIncomingPaths(filenames, source: "openDocument", forceNewWindow: true)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    logOpen("application openFile path=\(filename)")
    openPathInNewWindow(filename, source: "openDocument", forceNewWindow: true)
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      if url.scheme?.lowercased() == "d1vai" {
        logOpen("application open urls oauth url=\(url.absoluteString)")
        configureOAuthChannelsIfPossible()
        oauthCallbackStreamHandler.handle(url: url)
        continue
      }

      guard url.isFileURL else {
        logOpen("ignored non-file url=\(url.absoluteString)")
        continue
      }

      let path = url.path
      logOpen("application open urls file path=\(path)")
      openPathInNewWindow(path, source: "openDocument", forceNewWindow: true)
    }
  }

  func handleDroppedPaths(_ paths: [String], targetHostId: String) {
    logOpen("window drop target=\(targetHostId) count=\(paths.count)")
    for path in paths {
      enqueueOpenRequestIfNeeded(
        path: path,
        source: "windowDrop",
        openInNewWindow: false,
        targetHostId: targetHostId
      )
    }
    flushPendingOpenRequests(for: targetHostId)
  }

  @discardableResult
  private func openPathInNewWindow(
    _ path: String,
    source: String,
    forceNewWindow: Bool = false
  ) -> Bool {
    guard let request = buildOpenRequestIfNeeded(
      path: path,
      source: source,
      openInNewWindow: true
    ) else {
      return false
    }

    let workspacePath = derivedWorkspacePath(
      for: request.path,
      isDirectory: request.isDirectory
    )
    let workspaceTitle = recentWorkspaceTitle(
      workspacePath: workspacePath,
      entryPath: request.path
    )

    registerRecentWorkspace(
      entryPath: request.path,
      workspacePath: workspacePath,
      title: workspaceTitle
    )
    NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: request.path))

    logOpen(
      "open request source=\(source) path=\(request.path) directory=\(request.isDirectory)"
    )

    if !forceNewWindow, let existingHostIdentifier = existingWorkspaceHostIdentifier(for: request) {
      logOpen(
        "reused existing workspace host=\(existingHostIdentifier) path=\(request.path)"
      )
      enqueueOpenRequestIfNeeded(
        path: request.path,
        source: source,
        openInNewWindow: false,
        targetHostId: existingHostIdentifier
      )
      flushPendingOpenRequests(for: existingHostIdentifier)
      _ = activateWorkspaceWindow(hostIdentifier: existingHostIdentifier)
      return true
    }

    if openChannels[mainHostIdentifier] == nil && workspaceWindowControllers.isEmpty {
      logOpen("queued cold-start request for main window path=\(request.path)")
      pendingOpenRequests[mainHostIdentifier, default: []].append(request)
      return true
    }

    let hostIdentifier = UUID().uuidString
    let controller = FlutterSecondaryWindowController(hostIdentifier: hostIdentifier)
    controller.onWindowClosed = { [weak self] closedHostIdentifier in
      self?.workspaceWindowControllers.removeValue(forKey: closedHostIdentifier)
      self?.workspaceWindowStates.removeValue(forKey: closedHostIdentifier)
      self?.openChannels.removeValue(forKey: closedHostIdentifier)
      self?.windowChannels.removeValue(forKey: closedHostIdentifier)
      self?.hostWindows.removeValue(forKey: closedHostIdentifier)
      self?.pendingOpenRequests.removeValue(forKey: closedHostIdentifier)
      self?.pendingRouteRequests.removeValue(forKey: closedHostIdentifier)
      self?.broadcastWorkspaceWindowsChanged()
    }

    workspaceWindowControllers[hostIdentifier] = controller
    hostWindows[hostIdentifier] = WeakWindowReference(window: controller.window)
    controller.window?.title = request.windowTitle
    configureChannels(
      hostIdentifier: hostIdentifier,
      binaryMessenger: controller.engine.binaryMessenger,
      windowProvider: { [weak controller] in controller?.window },
      autoFlushPendingOpenRequests: false
    )
    pendingOpenRequests[hostIdentifier, default: []].append(request)
    logOpen("created workspace window host=\(hostIdentifier) title=\(request.windowTitle)")
    controller.showAndActivate()
    return true
  }

  private func handleIncomingPaths(
    _ paths: [String],
    source: String,
    forceNewWindow: Bool = false
  ) {
    for path in paths {
      openPathInNewWindow(path, source: source, forceNewWindow: forceNewWindow)
    }
  }

  private func configureChannels(
    hostIdentifier: String,
    binaryMessenger: FlutterBinaryMessenger,
    windowProvider: @escaping () -> NSWindow?,
    autoFlushPendingOpenRequests: Bool = true
  ) {
    let openChannel = FlutterMethodChannel(
      name: openChannelName,
      binaryMessenger: binaryMessenger
    )
    openChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window_unavailable", message: nil, details: nil))
        return
      }

      switch call.method {
      case "getHostIdentifier":
        result(hostIdentifier)
      case "listWorkspaceWindows":
        result(self.serializeWorkspaceWindows())
      case "takeInitialOpenRequest":
        let request = self.pendingOpenRequests[hostIdentifier]?.isEmpty == false
          ? self.pendingOpenRequests[hostIdentifier]?.removeFirst()
          : nil
        self.logOpen(
          "take initial request host=\(hostIdentifier) available=\(request != nil)"
        )
        result(request?.flutterArguments)
      case "activateWorkspaceWindow":
        guard
          let arguments = call.arguments as? [String: Any],
          let rawHostIdentifier = arguments["hostIdentifier"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing hostIdentifier for activateWorkspaceWindow",
              details: call.arguments
            )
          )
          return
        }
        result(self.activateWorkspaceWindow(hostIdentifier: rawHostIdentifier))
      case "setWorkspaceWindowState":
        guard let arguments = call.arguments as? [String: Any] else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing payload for setWorkspaceWindowState",
              details: call.arguments
            )
          )
          return
        }
        self.setWorkspaceWindowState(
          hostIdentifier: hostIdentifier,
          arguments: arguments,
          result: result
        )
      case "clearWorkspaceWindowState":
        self.clearWorkspaceWindowState(hostIdentifier: hostIdentifier)
        result(nil)
      case "openPathInNewWindow":
        guard
          let arguments = call.arguments as? [String: Any],
          let rawPath = arguments["path"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing path for openPathInNewWindow",
              details: call.arguments
            )
          )
          return
        }

        let source =
          (arguments["source"] as? String)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        let forceNewWindow = arguments["forceNewWindow"] as? Bool ?? false
        self.logOpen("flutter requested new window source=\(source ?? "menu") path=\(rawPath)")
        let opened = self.openPathInNewWindow(
          rawPath,
          source: source?.isEmpty == false ? source! : "menu",
          forceNewWindow: forceNewWindow
        )
        result(opened)
      case "openRouteInMainWindow":
        guard
          let arguments = call.arguments as? [String: Any],
          let rawRoute = arguments["route"] as? String
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing route for openRouteInMainWindow",
              details: call.arguments
            )
          )
          return
        }
        let activate = arguments["activate"] as? Bool ?? true
        result(self.openRouteInMainWindow(rawRoute, activate: activate))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    openChannels[hostIdentifier] = openChannel
    hostWindows[hostIdentifier] = WeakWindowReference(window: windowProvider())

    let windowChannel = FlutterMethodChannel(
      name: windowChannelName,
      binaryMessenger: binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "window_unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "beginWindowDrag":
        self.beginWindowDrag(windowProvider: windowProvider, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannels[hostIdentifier] = windowChannel

    if autoFlushPendingOpenRequests {
      flushPendingOpenRequests(for: hostIdentifier)
    }
    flushPendingRouteRequests(for: hostIdentifier)
  }

  private func configureOAuthChannels(binaryMessenger: FlutterBinaryMessenger) {
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

  private func configureOAuthChannelsIfPossible() {
    if oauthCallbackChannel != nil, oauthCallbackControlChannel != nil {
      return
    }

    guard let flutterViewController = extractFlutterViewController(from: mainFlutterWindow ?? NSApp.mainWindow) else {
      return
    }
    configureOAuthChannels(binaryMessenger: flutterViewController.engine.binaryMessenger)
  }

  private func extractFlutterViewController(from window: NSWindow?) -> FlutterViewController? {
    if let direct = window?.contentViewController as? FlutterViewController {
      return direct
    }
    if let root = window?.contentViewController as? RootContainerViewController {
      return root.flutterViewController
    }
    return window?.contentViewController?.children.first { child in
      child is FlutterViewController
    } as? FlutterViewController
  }

  private func beginWindowDrag(
    windowProvider: () -> NSWindow?,
    result: @escaping FlutterResult
  ) {
    let window = windowProvider()
    DispatchQueue.main.async {
      guard let window else {
        result(
          FlutterError(
            code: "window_unavailable",
            message: "Flutter host window not found",
            details: nil
          )
        )
        return
      }
      guard let event = NSApp.currentEvent else {
        result(
          FlutterError(
            code: "event_unavailable",
            message: "No current mouse event",
            details: nil
          )
        )
        return
      }
      window.performDrag(with: event)
      result(nil)
    }
  }

  private func enqueueOpenRequestIfNeeded(
    path: String,
    source: String,
    openInNewWindow: Bool,
    targetHostId: String
  ) {
    guard let request = buildOpenRequestIfNeeded(
      path: path,
      source: source,
      openInNewWindow: openInNewWindow
    ) else {
      return
    }
    pendingOpenRequests[targetHostId, default: []].append(request)
  }

  private func buildOpenRequestIfNeeded(
    path: String,
    source: String,
    openInNewWindow: Bool
  ) -> MacosOpenRequest? {
    let normalizedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedPath.isEmpty else {
      return nil
    }

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: normalizedPath, isDirectory: &isDirectory) else {
      logOpen("skipped missing path=\(normalizedPath)")
      return nil
    }

    if !isDirectory.boolValue && !FileManager.default.isReadableFile(atPath: normalizedPath) {
      logOpen("skipped unreadable file path=\(normalizedPath)")
      return nil
    }

    return MacosOpenRequest(
      path: normalizedPath,
      isDirectory: isDirectory.boolValue,
      source: source,
      openInNewWindow: openInNewWindow
    )
  }

  private func flushPendingOpenRequests(for hostIdentifier: String) {
    guard let channel = openChannels[hostIdentifier] else {
      return
    }
    guard let queued = pendingOpenRequests[hostIdentifier], !queued.isEmpty else {
      return
    }

    logOpen("flushing \(queued.count) request(s) to host=\(hostIdentifier)")
    pendingOpenRequests[hostIdentifier] = []
    for request in queued {
      channel.invokeMethod("openRequest", arguments: request.flutterArguments)
    }
  }

  private func flushPendingRouteRequests(for hostIdentifier: String) {
    guard let channel = openChannels[hostIdentifier] else {
      return
    }
    guard let queued = pendingRouteRequests[hostIdentifier], !queued.isEmpty else {
      return
    }

    logOpen("flushing \(queued.count) route(s) to host=\(hostIdentifier)")
    pendingRouteRequests[hostIdentifier] = []
    var shouldActivate = false
    for request in queued {
      channel.invokeMethod("openRoute", arguments: request.route)
      shouldActivate = shouldActivate || request.activate
    }
    if shouldActivate {
      _ = activateWorkspaceWindow(hostIdentifier: hostIdentifier)
    }
  }

  private func setWorkspaceWindowState(
    hostIdentifier: String,
    arguments: [String: Any],
    result: @escaping FlutterResult
  ) {
    guard
      let rawWorkspacePath = arguments["workspacePath"] as? String,
      let rawEntryPath = arguments["entryPath"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "workspacePath and entryPath are required",
          details: arguments
        )
      )
      return
    }

    let workspacePath = normalizedPath(rawWorkspacePath)
    let entryPath = normalizedPath(rawEntryPath)
    guard !workspacePath.isEmpty, !entryPath.isEmpty else {
      result(
        FlutterError(
          code: "invalid_path",
          message: "workspacePath and entryPath must be non-empty",
          details: arguments
        )
      )
      return
    }

    let rawTitle =
      (arguments["title"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fallbackTitle = URL(fileURLWithPath: workspacePath).lastPathComponent
    let title = rawTitle.isEmpty
      ? (fallbackTitle.isEmpty ? "Local Workspace" : fallbackTitle)
      : rawTitle

    workspaceWindowStates[hostIdentifier] = WorkspaceWindowState(
      hostIdentifier: hostIdentifier,
      workspacePath: workspacePath,
      entryPath: entryPath,
      title: title
    )
    logOpen(
      "workspace state host=\(hostIdentifier) workspace=\(workspacePath) entry=\(entryPath)"
    )
    registerRecentWorkspace(
      entryPath: entryPath,
      workspacePath: workspacePath,
      title: title
    )
    currentWindow(for: hostIdentifier)?.title = "d1v \(title)"
    broadcastWorkspaceWindowsChanged()
    result(nil)
  }

  private func clearWorkspaceWindowState(hostIdentifier: String) {
    workspaceWindowStates.removeValue(forKey: hostIdentifier)
    broadcastWorkspaceWindowsChanged()
  }

  private func normalizedPath(_ path: String) -> String {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return ""
    }
    return URL(fileURLWithPath: trimmed).standardizedFileURL.path
  }

  private func derivedWorkspacePath(for path: String, isDirectory: Bool) -> String {
    let normalized = normalizedPath(path)
    guard !normalized.isEmpty else {
      return ""
    }
    if isDirectory {
      return normalized
    }
    return URL(fileURLWithPath: normalized).deletingLastPathComponent().path
  }

  private func existingWorkspaceHostIdentifier(for request: MacosOpenRequest) -> String? {
    let workspacePath = derivedWorkspacePath(
      for: request.path,
      isDirectory: request.isDirectory
    )
    guard !workspacePath.isEmpty else {
      return nil
    }
    return workspaceWindowStates.values.first { state in
      state.workspacePath == workspacePath
    }?.hostIdentifier
  }

  private func currentWindow(for hostIdentifier: String) -> NSWindow? {
    if let window = hostWindows[hostIdentifier]?.window {
      return window
    }
    if hostIdentifier == mainHostIdentifier {
      return mainFlutterWindow
    }
    return workspaceWindowControllers[hostIdentifier]?.window
  }

  private func activateWorkspaceWindow(hostIdentifier: String) -> Bool {
    let trimmed = hostIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let window = currentWindow(for: trimmed) else {
      return false
    }
    DispatchQueue.main.async {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  @discardableResult
  private func openRouteInMainWindow(_ route: String, activate: Bool = true) -> Bool {
    let normalizedRoute = route.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedRoute.isEmpty else {
      return false
    }

    pendingRouteRequests[mainHostIdentifier, default: []].append(
      PendingRouteRequest(route: normalizedRoute, activate: activate)
    )
    logOpen("queued main route route=\(normalizedRoute) activate=\(activate)")
    flushPendingRouteRequests(for: mainHostIdentifier)
    if activate, openChannels[mainHostIdentifier] == nil {
      _ = activateWorkspaceWindow(hostIdentifier: mainHostIdentifier)
    }
    return true
  }

  private func serializeWorkspaceWindows() -> [[String: Any]] {
    return workspaceWindowStates.values.sorted { lhs, rhs in
      let lhsFocused = currentWindow(for: lhs.hostIdentifier)?.isKeyWindow == true
      let rhsFocused = currentWindow(for: rhs.hostIdentifier)?.isKeyWindow == true
      if lhsFocused != rhsFocused {
        return lhsFocused
      }
      if lhs.hostIdentifier == mainHostIdentifier || rhs.hostIdentifier == mainHostIdentifier {
        return lhs.hostIdentifier == mainHostIdentifier
      }
      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }.map { state in
      var payload = state.flutterArguments
      let window = currentWindow(for: state.hostIdentifier)
      payload["focused"] = window?.isKeyWindow == true
      payload["visible"] = window?.isVisible ?? true
      return payload
    }
  }

  private func broadcastWorkspaceWindowsChanged() {
    let payload = serializeWorkspaceWindows()
    for channel in openChannels.values {
      channel.invokeMethod("workspaceWindowsChanged", arguments: payload)
    }
  }

  private func recentWorkspaceTitle(workspacePath: String, entryPath: String) -> String {
    let workspaceLastSegment = URL(fileURLWithPath: workspacePath).lastPathComponent
    if !workspaceLastSegment.isEmpty {
      return workspaceLastSegment
    }
    return URL(fileURLWithPath: entryPath).lastPathComponent
  }

  private func loadRecentWorkspaceRecords() -> [RecentWorkspaceRecord] {
    guard
      let raw = UserDefaults.standard.array(forKey: recentWorkspaceDefaultsKey) as? [[String: Any]]
    else {
      return []
    }
    return raw.compactMap(RecentWorkspaceRecord.from(dictionary:)).sorted { lhs, rhs in
      lhs.seenAt > rhs.seenAt
    }
  }

  private func saveRecentWorkspaceRecords(_ records: [RecentWorkspaceRecord]) {
    let limited = Array(records.prefix(maxRecentWorkspaceCount))
    UserDefaults.standard.set(limited.map(\.dictionary), forKey: recentWorkspaceDefaultsKey)
  }

  private func registerRecentWorkspace(
    entryPath: String,
    workspacePath: String,
    title: String
  ) {
    let normalizedEntryPath = normalizedPath(entryPath)
    let normalizedWorkspacePath = normalizedPath(workspacePath)
    guard !normalizedEntryPath.isEmpty else {
      return
    }

    let record = RecentWorkspaceRecord(
      entryPath: normalizedEntryPath,
      workspacePath: normalizedWorkspacePath,
      title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      seenAt: Date().timeIntervalSince1970
    )

    let next = [record] + loadRecentWorkspaceRecords().filter { existing in
      existing.entryPath != normalizedEntryPath
    }
    saveRecentWorkspaceRecords(next)
  }

  private func removeRecentWorkspace(entryPath: String) {
    let normalizedEntryPath = normalizedPath(entryPath)
    guard !normalizedEntryPath.isEmpty else {
      return
    }
    let next = loadRecentWorkspaceRecords().filter { record in
      record.entryPath != normalizedEntryPath
    }
    saveRecentWorkspaceRecords(next)
  }

  private func clearRecentWorkspaces() {
    UserDefaults.standard.removeObject(forKey: recentWorkspaceDefaultsKey)
  }

  private func presentMissingRecentWorkspaceAlert(for path: String) {
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.messageText = "Path no longer exists"
      alert.informativeText =
        "d1v could not open this recent workspace because the path was removed:\n\n\(path)"
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }

  @objc
  private func handleDockRecentWorkspaceSelection(_ sender: NSMenuItem) {
    guard let selectedPath = (sender.representedObject as? NSString) as String? else {
      return
    }
    let normalizedSelectedPath = normalizedPath(selectedPath)
    guard !normalizedSelectedPath.isEmpty else {
      return
    }

    logOpen("dock recent selected path=\(normalizedSelectedPath)")

    let exists = FileManager.default.fileExists(atPath: normalizedSelectedPath)
    if !exists {
      removeRecentWorkspace(entryPath: normalizedSelectedPath)
      presentMissingRecentWorkspaceAlert(for: normalizedSelectedPath)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      let opened = self.openPathInNewWindow(
        normalizedSelectedPath,
        source: "dock",
        forceNewWindow: true
      )
      if opened {
        self.logOpen("dock recent opened path=\(normalizedSelectedPath)")
      } else {
        self.logOpen("dock recent open failed path=\(normalizedSelectedPath)")
        self.presentMissingRecentWorkspaceAlert(for: normalizedSelectedPath)
      }
    }
  }

  @objc
  private func handleDockClearRecentWorkspaces(_ sender: NSMenuItem) {
    clearRecentWorkspaces()
  }

  private func logOpen(_ message: String) {
    NSLog("[d1vai-open] %@", message)
  }
}
