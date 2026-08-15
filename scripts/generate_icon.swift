import Cocoa

func renderBrandIcon(size: CGFloat) -> NSImage {
    let nsSize = NSSize(width: size, height: size)
    let image = NSImage(size: nsSize, flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }

        let scale = size / 512.0
        context.saveGState()

        // macOS App Icon rounded squircle background (macOS 14 standard: ~22.5% corner radius)
        let bgPadding = 20.0 * scale
        let bgRect = CGRect(x: bgPadding, y: bgPadding, width: size - 2 * bgPadding, height: size - 2 * bgPadding)
        let bgCornerRadius = 106.0 * scale
        let bgPath = CGPath(roundedRect: bgRect, cornerWidth: bgCornerRadius, cornerHeight: bgCornerRadius, transform: nil)

        // Drop shadow under main squircle
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
        context.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1.0))
        context.addPath(bgPath)
        context.fillPath()
        context.restoreGState()

        // Squircle Gradient Fill
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bgColors = [
            CGColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0),
            CGColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
        ] as CFArray
        if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addPath(bgPath)
            context.clip()
            context.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: size - bgPadding), end: CGPoint(x: 0, y: bgPadding), options: [])
            context.restoreGState()
        }

        // Squircle subtle inner border
        context.setLineWidth(2.0 * scale)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.15))
        context.addPath(bgPath)
        context.strokePath()

        // 2. Metallic Clipboard Plate
        let plateWidth = 320.0 * scale
        let plateHeight = 360.0 * scale
        let plateX = (size - plateWidth) / 2.0
        let plateY = 60.0 * scale
        let plateRect = CGRect(x: plateX, y: plateY, width: plateWidth, height: plateHeight)
        let platePath = CGPath(roundedRect: plateRect, cornerWidth: 32.0 * scale, cornerHeight: 32.0 * scale, transform: nil)

        // Plate drop shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 16 * scale, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
        context.setFillColor(CGColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0))
        context.addPath(platePath)
        context.fillPath()
        context.restoreGState()

        // Plate metallic gradient
        let plateColors = [
            CGColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0),
            CGColor(red: 0.75, green: 0.78, blue: 0.84, alpha: 1.0)
        ] as CFArray
        if let plateGradient = CGGradient(colorsSpace: colorSpace, colors: plateColors, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addPath(platePath)
            context.clip()
            context.drawLinearGradient(plateGradient, start: CGPoint(x: 0, y: plateY + plateHeight), end: CGPoint(x: 0, y: plateY), options: [])
            context.restoreGState()
        }

        // Plate highlight border
        context.setLineWidth(2.0 * scale)
        context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8))
        context.addPath(platePath)
        context.strokePath()

        // 3. Top metallic bracket with center pinhole
        let bracketWidth = 140.0 * scale
        let bracketHeight = 56.0 * scale
        let bracketX = (size - bracketWidth) / 2.0
        let bracketY = plateY + plateHeight - 24.0 * scale
        let bracketRect = CGRect(x: bracketX, y: bracketY, width: bracketWidth, height: bracketHeight)
        let bracketPath = CGPath(roundedRect: bracketRect, cornerWidth: 16.0 * scale, cornerHeight: 16.0 * scale, transform: nil)

        // Bracket shadow
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 6 * scale, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
        context.setFillColor(CGColor(red: 0.50, green: 0.53, blue: 0.58, alpha: 1.0))
        context.addPath(bracketPath)
        context.fillPath()
        context.restoreGState()

        // Bracket gradient
        let bracketColors = [
            CGColor(red: 0.68, green: 0.71, blue: 0.77, alpha: 1.0),
            CGColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1.0)
        ] as CFArray
        if let bracketGradient = CGGradient(colorsSpace: colorSpace, colors: bracketColors, locations: [0.0, 1.0]) {
            context.saveGState()
            context.addPath(bracketPath)
            context.clip()
            context.drawLinearGradient(bracketGradient, start: CGPoint(x: 0, y: bracketY + bracketHeight), end: CGPoint(x: 0, y: bracketY), options: [])
            context.restoreGState()
        }

        // Pinhole in bracket
        let pinholeRadius = 10.0 * scale
        let pinholeCenter = CGPoint(x: size / 2.0, y: bracketY + bracketHeight / 2.0)
        let pinholeRect = CGRect(x: pinholeCenter.x - pinholeRadius, y: pinholeCenter.y - pinholeRadius, width: pinholeRadius * 2, height: pinholeRadius * 2)
        context.saveGState()
        context.setFillColor(CGColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0))
        context.addEllipse(in: pinholeRect)
        context.fillPath()
        context.restoreGState()

        // 4. Glowing Electric Cyan Checkmark
        let checkPath = CGMutablePath()
        checkPath.move(to: CGPoint(x: size / 2.0 - 64 * scale, y: plateY + 160 * scale))
        checkPath.addLine(to: CGPoint(x: size / 2.0 - 12 * scale, y: plateY + 95 * scale))
        checkPath.addLine(to: CGPoint(x: size / 2.0 + 78 * scale, y: plateY + 225 * scale))

        // Checkmark outer glow
        context.saveGState()
        context.setShadow(offset: .zero, blur: 28 * scale, color: CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9))
        context.setLineWidth(36.0 * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(CGColor(red: 0.0, green: 0.55, blue: 1.0, alpha: 1.0))
        context.addPath(checkPath)
        context.strokePath()
        context.restoreGState()

        // Checkmark bright cyan core
        context.setLineWidth(22.0 * scale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(CGColor(red: 0.05, green: 0.92, blue: 1.0, alpha: 1.0))
        context.addPath(checkPath)
        context.strokePath()

        // Checkmark white specular center line
        context.setLineWidth(8.0 * scale)
        context.setStrokeColor(CGColor(red: 0.85, green: 1.0, blue: 1.0, alpha: 0.95))
        context.addPath(checkPath)
        context.strokePath()

        context.restoreGState()
        return true
    }
    return image
}

func savePNG(image: NSImage, path: String, pixelSize: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize), from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
let currentDir = fm.currentDirectoryPath
let iconsetDir = "\(currentDir)/Resources/AppIcon.iconset"
let resourcesDir = "\(currentDir)/Resources"

try? fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
try? fm.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

let iconSizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 16),
    ("icon_16x16@2x.png", 16, 32),
    ("icon_32x32.png", 32, 32),
    ("icon_32x32@2x.png", 32, 64),
    ("icon_128x128.png", 128, 128),
    ("icon_128x128@2x.png", 128, 256),
    ("icon_256x256.png", 256, 256),
    ("icon_256x256@2x.png", 256, 512),
    ("icon_512x512.png", 512, 512),
    ("icon_512x512@2x.png", 512, 1024)
]

print("🎨 Generating ClipBo macOS AppIcon assets...")
for (name, pointSize, pixelSize) in iconSizes {
    let img = renderBrandIcon(size: CGFloat(pixelSize))
    let filePath = "\(iconsetDir)/\(name)"
    savePNG(image: img, path: filePath, pixelSize: pixelSize)
    print("  📸 Generated \(name) (\(pixelSize)×\(pixelSize)px)")
}

let icnsPath = "\(resourcesDir)/AppIcon.icns"
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir, "-o", icnsPath]
try! task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ AppIcon.icns generated successfully at: \(icnsPath)")
} else {
    print("❌ Failed to generate AppIcon.icns with iconutil (exit code: \(task.terminationStatus))")
    exit(1)
}
