import Cocoa
import FlutterMacOS

final class DirectoryDropOverlayView: NSView {
  weak var appDelegate: AppDelegate?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL])
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    return .copy
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    return nil
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let pasteboardItems = sender.draggingPasteboard.pasteboardItems ?? []
    let paths = pasteboardItems.compactMap { item in
      item.string(forType: .fileURL)
    }.compactMap { raw in
      URL(string: raw)?.path
    }

    guard !paths.isEmpty else {
      return false
    }

    appDelegate?.handleDroppedPaths(paths)
    return true
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    if let contentView = self.contentView {
      let overlay = DirectoryDropOverlayView(frame: contentView.bounds)
      overlay.autoresizingMask = [.width, .height]
      overlay.appDelegate = NSApp.delegate as? AppDelegate
      overlay.wantsLayer = true
      overlay.layer?.backgroundColor = NSColor.clear.cgColor
      contentView.addSubview(overlay, positioned: .above, relativeTo: nil)
    }

    super.awakeFromNib()
  }
}
