import Cocoa
import FlutterMacOS

final class NonDraggableHostingView: NSView {
  override var mouseDownCanMoveWindow: Bool {
    return false
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    return true
  }
}

final class RootContainerViewController: NSViewController {
  let flutterViewController: FlutterViewController

  init(flutterViewController: FlutterViewController) {
    self.flutterViewController = flutterViewController
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    self.view = NonDraggableHostingView()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    addChild(flutterViewController)
    let flutterView = flutterViewController.view
    flutterView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(flutterView)

    NSLayoutConstraint.activate([
      flutterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      flutterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      flutterView.topAnchor.constraint(equalTo: view.topAnchor),
      flutterView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }
}

final class DirectoryDropOverlayView: NSView {
  private let messageField = NSTextField(labelWithString: "Drop folder or file to open")
  private let detailField = NSTextField(
    labelWithString: "Open locally, attach to a project, or import to cloud"
  )
  private let borderLayer = CAShapeLayer()
  private let panelLayer = CAShapeLayer()
  private var isShowingDropState = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupOverlay()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupOverlay()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return isShowingDropState ? self : nil
  }

  override func layout() {
    super.layout()
    borderLayer.frame = bounds
    borderLayer.path = CGPath(
      roundedRect: bounds.insetBy(dx: 20, dy: 20),
      cornerWidth: 22,
      cornerHeight: 22,
      transform: nil
    )

    let panelSize = NSSize(width: min(max(bounds.width - 80, 320), 460), height: 116)
    let panelOrigin = NSPoint(
      x: (bounds.width - panelSize.width) / 2,
      y: (bounds.height - panelSize.height) / 2
    )
    panelLayer.frame = bounds
    panelLayer.path = CGPath(
      roundedRect: NSRect(origin: panelOrigin, size: panelSize),
      cornerWidth: 20,
      cornerHeight: 20,
      transform: nil
    )

    messageField.frame = NSRect(
      x: panelOrigin.x + 24,
      y: panelOrigin.y + 60,
      width: panelSize.width - 48,
      height: 24
    )
    detailField.frame = NSRect(
      x: panelOrigin.x + 24,
      y: panelOrigin.y + 32,
      width: panelSize.width - 48,
      height: 20
    )
  }

  func updateDropState(visible: Bool) {
    isShowingDropState = visible
    borderLayer.isHidden = !visible
    panelLayer.isHidden = !visible
    messageField.isHidden = !visible
    detailField.isHidden = !visible
  }

  private func setupOverlay() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    borderLayer.fillColor = NSColor(calibratedWhite: 0.05, alpha: 0.22).cgColor
    borderLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.95).cgColor
    borderLayer.lineWidth = 2
    borderLayer.lineDashPattern = [10, 8]
    borderLayer.isHidden = true
    layer?.addSublayer(borderLayer)

    panelLayer.fillColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
    panelLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
    panelLayer.lineWidth = 1
    panelLayer.shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
    panelLayer.shadowOpacity = 1
    panelLayer.shadowRadius = 20
    panelLayer.shadowOffset = CGSize(width: 0, height: 10)
    panelLayer.isHidden = true
    layer?.addSublayer(panelLayer)

    messageField.alignment = .center
    messageField.font = .systemFont(ofSize: 24, weight: .bold)
    messageField.textColor = .labelColor
    messageField.backgroundColor = .clear
    messageField.isBordered = false
    messageField.isEditable = false
    messageField.isHidden = true
    addSubview(messageField)

    detailField.alignment = .center
    detailField.font = .systemFont(ofSize: 13, weight: .medium)
    detailField.textColor = .secondaryLabelColor
    detailField.backgroundColor = .clear
    detailField.isBordered = false
    detailField.isEditable = false
    detailField.isHidden = true
    addSubview(detailField)
  }
}

final class SecondaryFlutterWindow: NSWindow {
  let hostIdentifier: String
  weak var dropDelegate: FlutterSecondaryWindowController?
  private weak var dropOverlay: DirectoryDropOverlayView?

  init(hostIdentifier: String, contentRect: NSRect) {
    self.hostIdentifier = hostIdentifier
    super.init(
      contentRect: contentRect,
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
  }

  func installDropOverlay() {
    // In-window file drops are handled by the Flutter desktop_drop layer so
    // users keep the "attach / import / open locally" flow. Native handling is
    // only used for Dock/open-document events.
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    dropOverlay?.updateDropState(visible: false)
  }

  func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return !extractPaths(from: sender).isEmpty
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = extractPaths(from: sender)
    dropOverlay?.updateDropState(visible: false)
    guard !paths.isEmpty else {
      return false
    }
    dropDelegate?.handleDroppedPaths(paths)
    return true
  }

  func concludeDragOperation(_ sender: NSDraggingInfo?) {
    dropOverlay?.updateDropState(visible: false)
  }

  private func extractPaths(from sender: NSDraggingInfo) -> [String] {
    return extractFilePaths(from: sender.draggingPasteboard)
  }
}

class MainFlutterWindow: NSWindow {
  let hostIdentifier = "main"
  private weak var dropOverlay: DirectoryDropOverlayView?
  private weak var flutterViewController: FlutterViewController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.flutterViewController = flutterViewController
    installFlutterContent(flutterViewController)
    RegisterGeneratedPlugins(registry: flutterViewController)
    (NSApp.delegate as? AppDelegate)?.registerMainWindow(
      self,
      flutterViewController: flutterViewController
    )
    super.awakeFromNib()
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    dropOverlay?.updateDropState(visible: false)
  }

  func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return !extractPaths(from: sender).isEmpty
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = extractPaths(from: sender)
    dropOverlay?.updateDropState(visible: false)
    guard !paths.isEmpty else {
      return false
    }
    (NSApp.delegate as? AppDelegate)?.handleDroppedPaths(paths, targetHostId: hostIdentifier)
    return true
  }

  func concludeDragOperation(_ sender: NSDraggingInfo?) {
    dropOverlay?.updateDropState(visible: false)
  }

  private func installFlutterContent(_ flutterViewController: FlutterViewController) {
    let rootViewController = RootContainerViewController(
      flutterViewController: flutterViewController
    )
    let windowFrame = self.frame
    self.contentViewController = rootViewController
    self.setFrame(windowFrame, display: true)
    configureWindowChrome()
  }

  private func configureWindowChrome() {
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = false
    self.styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unifiedCompact
    }
  }

  private func extractPaths(from sender: NSDraggingInfo) -> [String] {
    return extractFilePaths(from: sender.draggingPasteboard)
  }
}

final class FlutterSecondaryWindowController: NSWindowController, NSWindowDelegate {
  private static let defaultContentSize = NSSize(width: 1400, height: 920)
  private static let minimumContentSize = NSSize(width: 960, height: 640)

  let hostIdentifier: String
  let engine: FlutterEngine
  let flutterViewController: FlutterViewController
  var onWindowClosed: ((String) -> Void)?

  init(hostIdentifier: String) {
    self.hostIdentifier = hostIdentifier
    self.engine = FlutterEngine(
      name: "workspace-\(hostIdentifier)",
      project: nil,
      allowHeadlessExecution: true
    )
    _ = engine.run(withEntrypoint: "workspaceMain")
    self.flutterViewController = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )

    let window = SecondaryFlutterWindow(
      hostIdentifier: hostIdentifier,
      contentRect: NSRect(origin: .zero, size: Self.defaultContentSize)
    )
    window.title = "d1v Local Workspace"
    super.init(window: window)

    RegisterGeneratedPlugins(registry: engine)
    configureWindow(window)
    window.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showAndActivate() {
    guard let window else {
      return
    }
    applyDefaultFrame(to: window)
    showWindow(nil)
    window.contentView?.layoutSubtreeIfNeeded()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_ notification: Notification) {
    engine.shutDownEngine()
    onWindowClosed?(hostIdentifier)
  }

  func handleDroppedPaths(_ paths: [String]) {
    (NSApp.delegate as? AppDelegate)?.handleDroppedPaths(paths, targetHostId: hostIdentifier)
  }

  private func configureWindow(_ window: NSWindow) {
    let rootViewController = RootContainerViewController(
      flutterViewController: flutterViewController
    )
    window.contentViewController = rootViewController
    window.contentMinSize = Self.minimumContentSize
    window.minSize = NSSize(width: 980, height: 680)
    applyDefaultFrame(to: window)
    window.center()
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = false
    window.styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      window.toolbarStyle = .unifiedCompact
    }
    if let dragAwareWindow = window as? SecondaryFlutterWindow {
      dragAwareWindow.dropDelegate = self
      dragAwareWindow.installDropOverlay()
    }
  }

  private func applyDefaultFrame(to window: NSWindow) {
    let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 80, y: 80, width: 1440, height: 900)
    let width = min(Self.defaultContentSize.width, max(Self.minimumContentSize.width, visibleFrame.width - 96))
    let height = min(Self.defaultContentSize.height, max(Self.minimumContentSize.height, visibleFrame.height - 96))
    let frame = NSRect(
      x: visibleFrame.midX - width / 2,
      y: visibleFrame.midY - height / 2,
      width: width,
      height: height
    )
    window.setFrame(frame, display: true)
  }
}

private func extractFilePaths(from pasteboard: NSPasteboard) -> [String] {
  let options: [NSPasteboard.ReadingOptionKey: Any] = [
    .urlReadingFileURLsOnly: true,
  ]
  let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
  return urls?.map(\.path) ?? []
}
