import Cocoa

/// Provides vector/template icons and brand representations matching the ClipBo visual identity.
public enum ClipBoIconProvider {
    /// Generates a sharp, macOS-native template icon (20×20pt) representing the ClipBo clipboard with pinhole and checkmark.
    public static func menuBarTemplateImage() -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.saveGState()

            // 1. Draw Outer Clipboard Frame (Rounded Rectangle)
            let bodyRect = CGRect(x: 3.2, y: 1.8, width: 13.6, height: 14.4)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: 3.2, cornerHeight: 3.2, transform: nil)
            
            context.setLineWidth(1.7)
            context.setStrokeColor(NSColor.black.cgColor)
            context.addPath(bodyPath)
            context.strokePath()

            // 2. Draw Top Clip Bracket with Center Pinhole
            let clipTabRect = CGRect(x: 6.8, y: 14.4, width: 6.4, height: 4.0)
            let clipTabPath = CGPath(roundedRect: clipTabRect, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil)
            
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(clipTabPath)
            context.fillPath()

            // Top rounded pinhole
            let pinholeRect = CGRect(x: 8.6, y: 15.6, width: 2.8, height: 2.8)
            context.setFillColor(NSColor.white.cgColor)
            context.setBlendMode(.clear)
            context.addEllipse(in: pinholeRect)
            context.fillPath()

            // 3. Draw Bold Checkmark Inside
            context.setBlendMode(.normal)
            let checkmarkPath = CGMutablePath()
            checkmarkPath.move(to: CGPoint(x: 6.8, y: 8.6))
            checkmarkPath.addLine(to: CGPoint(x: 9.3, y: 5.6))
            checkmarkPath.addLine(to: CGPoint(x: 13.8, y: 11.2))

            context.setLineWidth(2.0)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(NSColor.black.cgColor)
            context.addPath(checkmarkPath)
            context.strokePath()

            context.restoreGState()
            return true
        }

        image.isTemplate = true
        return image
    }

    /// Generates the full-color glowing ClipBo brand icon at any requested square size.
    public static func brandIcon(size: CGFloat = 64) -> NSImage {
        let nsSize = NSSize(width: size, height: size)
        let image = NSImage(size: nsSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let scale = size / 64.0
            context.saveGState()

            // 1. Dark squircle background
            let bgRect = CGRect(x: 2 * scale, y: 2 * scale, width: 60 * scale, height: 60 * scale)
            let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil)
            context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
            context.addPath(bgPath)
            context.fillPath()

            // 2. Metallic silver clipboard plate
            let plateRect = CGRect(x: 10 * scale, y: 7 * scale, width: 44 * scale, height: 46 * scale)
            let platePath = CGPath(roundedRect: plateRect, cornerWidth: 8 * scale, cornerHeight: 8 * scale, transform: nil)
            
            // Gradient fill on plate
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let plateColors = [
                CGColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1.0),
                CGColor(red: 0.70, green: 0.73, blue: 0.78, alpha: 1.0)
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: plateColors, locations: [0.0, 1.0]) {
                context.saveGState()
                context.addPath(platePath)
                context.clip()
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 53 * scale), end: CGPoint(x: 0, y: 7 * scale), options: [])
                context.restoreGState()
            }

            // Plate border
            context.setLineWidth(1.5 * scale)
            context.setStrokeColor(CGColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 0.8))
            context.addPath(platePath)
            context.strokePath()

            // 3. Top metallic bracket with pinhole
            let bracketRect = CGRect(x: 22 * scale, y: 47 * scale, width: 20 * scale, height: 10 * scale)
            let bracketPath = CGPath(roundedRect: bracketRect, cornerWidth: 3 * scale, cornerHeight: 3 * scale, transform: nil)
            context.setFillColor(CGColor(red: 0.55, green: 0.58, blue: 0.64, alpha: 1.0))
            context.addPath(bracketPath)
            context.fillPath()

            // 4. Glowing Cyan/Electric Blue Checkmark
            let checkPath = CGMutablePath()
            checkPath.move(to: CGPoint(x: 21 * scale, y: 28 * scale))
            checkPath.addLine(to: CGPoint(x: 29 * scale, y: 19 * scale))
            checkPath.addLine(to: CGPoint(x: 44 * scale, y: 37 * scale))

            // Outer cyan glow
            context.saveGState()
            context.setShadow(offset: .zero, blur: 8 * scale, color: CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.85))
            context.setLineWidth(6.5 * scale)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0))
            context.addPath(checkPath)
            context.strokePath()
            context.restoreGState()

            // Inner bright neon cyan core
            context.setLineWidth(4.0 * scale)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(CGColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0))
            context.addPath(checkPath)
            context.strokePath()

            context.restoreGState()
            return true
        }
        return image
    }
}
