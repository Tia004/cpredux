import Cocoa

func generateIconSet() {
    let fm = FileManager.default
    let iconsetDir = "assets/branding/dmg_logo.iconset"
    try? fm.removeItem(atPath: iconsetDir)
    try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true, attributes: nil)

    guard let logo = NSImage(contentsOfFile: "assets/branding/CPReduxLogo.png") else {
        print("Error: Could not load CPReduxLogo.png")
        return
    }

    let sizes: [(String, CGFloat)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    for (name, size) in sizes {
        let img = NSImage(size: NSSize(width: size, height: size))
        img.lockFocus()
        
        // Mantieni proporzioni del logo (965x353) centrandolo su sfondo trasparente
        let aspect: CGFloat = 353.0 / 965.0
        let targetWidth = size * 0.95
        let targetHeight = targetWidth * aspect
        let rect = NSRect(
            x: (size - targetWidth) / 2,
            y: (size - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
        logo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        img.unlockFocus()

        if let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let path = "\(iconsetDir)/\(name)"
            try? pngData.write(to: URL(fileURLWithPath: path))
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetDir, "-o", "assets/branding/dmg_logo.icns"]
    try? process.run()
    process.waitUntilExit()

    try? fm.removeItem(atPath: iconsetDir)
    print("Generated: assets/branding/dmg_logo.icns successfully")
}

generateIconSet()
