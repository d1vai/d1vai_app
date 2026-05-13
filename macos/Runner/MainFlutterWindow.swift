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
  private let flutterViewController: FlutterViewController

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
  private let messageField = NSTextField(labelWithString: "Drop folder or file to import")
  private let detailField = NSTextField(labelWithString: "Imports to cloud, then opens Code chat")
  private let borderLayer = CAShapeLayer()
  private let panelLayer = CAShapeLayer()
  private var isShowingDropState = false

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL])
    setupOverlay()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL])
    setupOverlay()
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] overlay draggingEntered hasPaths=%@", hasImportablePaths ? "true" : "false")
    updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] overlay draggingUpdated hasPaths=%@", hasImportablePaths ? "true" : "false")
    updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    NSLog("[d1vai-drop] overlay draggingExited")
    updateDropState(visible: false)
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let ok = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] overlay prepareForDragOperation ok=%@", ok ? "true" : "false")
    return ok
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = extractPaths(from: sender)
    NSLog("[d1vai-drop] overlay performDragOperation paths=%@", paths.joined(separator: " | "))
    updateDropState(visible: false)

    guard !paths.isEmpty else {
      return false
    }

    (NSApp.delegate as? AppDelegate)?.handleDroppedPaths(paths)
    return true
  }

  override func concludeDragOperation(_ sender: NSDraggingInfo?) {
    NSLog("[d1vai-drop] overlay concludeDragOperation")
    updateDropState(visible: false)
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

    let panelSize = NSSize(width: min(max(bounds.width - 80, 280), 420), height: 112)
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
      y: panelOrigin.y + 58,
      width: panelSize.width - 48,
      height: 24
    )
    detailField.frame = NSRect(
      x: panelOrigin.x + 24,
      y: panelOrigin.y + 32,
      width: panelSize.width - 48,
      height: 18
    )
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

  func updateDropState(visible: Bool) {
    isShowingDropState = visible
    borderLayer.isHidden = !visible
    panelLayer.isHidden = !visible
    messageField.isHidden = !visible
    detailField.isHidden = !visible
  }

  private func extractPaths(from sender: NSDraggingInfo) -> [String] {
    return extractFilePaths(from: sender.draggingPasteboard)
  }
}

class MainFlutterWindow: NSWindow {
  private weak var dropOverlay: DirectoryDropOverlayView?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let rootViewController = RootContainerViewController(
      flutterViewController: flutterViewController
    )
    let windowFrame = self.frame
    self.contentViewController = rootViewController
    self.setFrame(windowFrame, display: true)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = false
    self.styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      self.toolbarStyle = .unifiedCompact
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerForDraggedTypes([.fileURL])
    (NSApp.delegate as? AppDelegate)?.configureOpenChannel(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    if let contentView = self.contentView {
      let overlay = DirectoryDropOverlayView(frame: contentView.bounds)
      overlay.autoresizingMask = [.width, .height]
      overlay.wantsLayer = true
      overlay.layer?.backgroundColor = NSColor.clear.cgColor
      contentView.addSubview(overlay, positioned: .above, relativeTo: nil)
      dropOverlay = overlay
    }

    super.awakeFromNib()
  }

  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] window draggingEntered hasPaths=%@", hasImportablePaths ? "true" : "false")
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    let hasImportablePaths = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] window draggingUpdated hasPaths=%@", hasImportablePaths ? "true" : "false")
    dropOverlay?.updateDropState(visible: hasImportablePaths)
    return hasImportablePaths ? .copy : []
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    NSLog("[d1vai-drop] window draggingExited")
    dropOverlay?.updateDropState(visible: false)
  }

  func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let ok = !extractPaths(from: sender).isEmpty
    NSLog("[d1vai-drop] window prepareForDragOperation ok=%@", ok ? "true" : "false")
    return ok
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let paths = extractPaths(from: sender)
    NSLog("[d1vai-drop] window performDragOperation paths=%@", paths.joined(separator: " | "))
    dropOverlay?.updateDropState(visible: false)

    guard !paths.isEmpty else {
      return false
    }

    (NSApp.delegate as? AppDelegate)?.handleDroppedPaths(paths)
    return true
  }

  func concludeDragOperation(_ sender: NSDraggingInfo?) {
    NSLog("[d1vai-drop] window concludeDragOperation")
    dropOverlay?.updateDropState(visible: false)
  }

  private func extractPaths(from sender: NSDraggingInfo) -> [String] {
    return extractFilePaths(from: sender.draggingPasteboard)
  }
}

private func extractFilePaths(from pasteboard: NSPasteboard) -> [String] {
  let options: [NSPasteboard.ReadingOptionKey: Any] = [
    .urlReadingFileURLsOnly: true,
  ]
  let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
  return urls?.map(\.path) ?? []
}
