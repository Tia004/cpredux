import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Configurazione barra del titolo immersiva trasparente
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.isOpaque = false
    self.backgroundColor = NSColor(red: 13.0 / 255.0, green: 14.0 / 255.0, blue: 18.0 / 255.0, alpha: 1.0)
    self.isMovableByWindowBackground = true

    // Dimensione minima garantita
    self.minSize = NSSize(width: 1024, height: 700)

    // Se l'utente ha una dimensione salvata dalle sessioni precedenti la ripristina;
    // altrimenti parte con una dimensione ampia (1360 x 900) centrata sullo schermo.
    let restored = self.setFrameUsingName("cpredux_main_window")
    if !restored || self.frame.width < 1024 || self.frame.height < 700 {
      let targetWidth: CGFloat = 1360
      let targetHeight: CGFloat = 900
      if let screen = NSScreen.main {
        let screenFrame = screen.visibleFrame
        let w = min(targetWidth, screenFrame.width * 0.95)
        let h = min(targetHeight, screenFrame.height * 0.95)
        let x = screenFrame.origin.x + (screenFrame.width - w) / 2
        let y = screenFrame.origin.y + (screenFrame.height - h) / 2
        self.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
      } else {
        self.setFrame(NSRect(x: 100, y: 100, width: targetWidth, height: targetHeight), display: true)
      }
    }

    // Salva automaticamente qualsiasi spostamento o ridimensionamento futuro
    self.setFrameAutosaveName("cpredux_main_window")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
