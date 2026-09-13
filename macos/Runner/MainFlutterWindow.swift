import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Configurazione barra del titolo immersiva trasparente
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false
    self.backgroundColor = NSColor(red: 13.0 / 255.0, green: 14.0 / 255.0, blue: 18.0 / 255.0, alpha: 1.0)
    self.isMovableByWindowBackground = true

    // Dimensione minima della finestra
    self.minSize = NSSize(width: 952, height: 800)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
