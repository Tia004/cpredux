import Cocoa

func generateBackground(width: CGFloat, height: CGFloat, scale: CGFloat, outputPath: String) {
    let size = NSSize(width: width * scale, height: height * scale)
    let image = NSImage(size: size)
    image.lockFocus()

    // Sfondo bianco puro
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    // Logo ufficiale dell'applicazione (CPReduxLogo.png) in grande trasparente al 50%
    let logoPath = "assets/branding/CPReduxLogo.png"
    if let logoImage = NSImage(contentsOfFile: logoPath) {
        let logoWidth: CGFloat = 500 * scale
        let logoHeight: CGFloat = logoWidth * (353.0 / 965.0) // Mantiene il rapporto d'aspetto originale
        let logoRect = NSRect(
            x: (size.width - logoWidth) / 2,
            y: (size.height - logoHeight) / 2,
            width: logoWidth,
            height: logoHeight
        )
        logoImage.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 0.50)
    }

    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Generated: \(outputPath) (\(Int(size.width))x\(Int(size.height)))")
    }
}

generateBackground(width: 660, height: 400, scale: 1.0, outputPath: "assets/branding/dmg_background.png")
generateBackground(width: 660, height: 400, scale: 2.0, outputPath: "assets/branding/dmg_background@2x.png")
