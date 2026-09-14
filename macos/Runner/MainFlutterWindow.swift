import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Imposta dimensioni ampie predefinite (1360 x 860) e centra sullo schermo
    let targetWidth: CGFloat = 1360
    let targetHeight: CGFloat = 860
    if let screen = NSScreen.main {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
      let y = screenFrame.origin.y + (screenFrame.height - targetHeight) / 2
      self.setFrame(NSRect(x: x, y: y, width: targetWidth, height: targetHeight), display: true)
    } else {
      self.setFrame(NSRect(x: 100, y: 100, width: targetWidth, height: targetHeight), display: true)
    }

    // Configurazione barra del titolo immersiva trasparente
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false
    self.backgroundColor = NSColor(red: 13.0 / 255.0, green: 14.0 / 255.0, blue: 18.0 / 255.0, alpha: 1.0)
    self.isMovableByWindowBackground = true

    // Dimensione minima garantita (sempre inferiore alla dimensione iniziale per evitare scatti)
    self.minSize = NSSize(width: 1024, height: 700)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
