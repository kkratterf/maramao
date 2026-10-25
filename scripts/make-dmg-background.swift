// Draws the background of the Maramao DMG window with CoreGraphics and
// CoreText, in the same palette as the app icon (scripts/make-icon.swift).
// Usage: swift scripts/make-dmg-background.swift <out-dir>
// Writes <out-dir>/background.png (660x400) and background@2x.png
// (1320x800). Combine them with:
//   tiffutil -cathidpicheck background.png background@2x.png -out background.tiff
//
// The design space is 660x400 points, origin bottom-left. Finder places
// the icons (top-left origin) with Maramao.app centred at (165, 200) and
// Applications at (495, 200), so the arrow runs between those two slots.
// Finder's window bounds include the title bar, so the bottom ~28 points
// may be hidden: nothing important is drawn there.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let width: CGFloat = 660
let height: CGFloat = 400

// MARK: - Helpers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    return CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations)!
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
    return CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
}

/// A font by PostScript name, falling back to the system UI font.
func font(_ names: [String], size: CGFloat) -> CTFont {
    for name in names {
        let candidate = CTFontCreateWithName(name as CFString, size, nil)
        let actual = CTFontCopyPostScriptName(candidate) as String
        if actual == name {
            return candidate
        }
    }
    if let system = CTFontCreateUIFontForLanguage(.system, size, nil) {
        return system
    }
    return CTFontCreateWithName("Helvetica" as CFString, size, nil)
}

/// Draws one line of text horizontally centred on `centerX`, with its
/// baseline at `baselineY`.
func drawCenteredText(_ text: String, in ctx: CGContext, font: CTFont, color: CGColor, centerX: CGFloat, baselineY: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: centerX - lineWidth / 2, y: baselineY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// A cat paw print centred at `center`, rotated so the toes point along
/// `angle` (radians, 0 = +x).
func drawPaw(in ctx: CGContext, center: CGPoint, angle: CGFloat, size: CGFloat, color: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: angle - CGFloat.pi / 2)
    ctx.setFillColor(color)
    // Main pad: a rounded triangle-ish blob.
    let pad = CGMutablePath()
    pad.move(to: CGPoint(x: 0, y: size * 0.18))
    pad.addCurve(to: CGPoint(x: size * 0.42, y: -size * 0.22),
                 control1: CGPoint(x: size * 0.26, y: size * 0.18),
                 control2: CGPoint(x: size * 0.46, y: -size * 0.02))
    pad.addCurve(to: CGPoint(x: -size * 0.42, y: -size * 0.22),
                 control1: CGPoint(x: size * 0.36, y: -size * 0.46),
                 control2: CGPoint(x: -size * 0.36, y: -size * 0.46))
    pad.addCurve(to: CGPoint(x: 0, y: size * 0.18),
                 control1: CGPoint(x: -size * 0.46, y: -size * 0.02),
                 control2: CGPoint(x: -size * 0.26, y: size * 0.18))
    pad.closeSubpath()
    ctx.addPath(pad)
    // Four toe beans.
    ctx.addPath(ellipse(-size * 0.40, size * 0.30, size * 0.13, size * 0.17))
    ctx.addPath(ellipse(-size * 0.15, size * 0.50, size * 0.13, size * 0.17))
    ctx.addPath(ellipse(size * 0.15, size * 0.50, size * 0.13, size * 0.17))
    ctx.addPath(ellipse(size * 0.40, size * 0.30, size * 0.13, size * 0.17))
    ctx.fillPath()
    ctx.restoreGState()
}

/// A point on a quadratic Bezier curve.
func quadPoint(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
                   y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y)
}

/// The tangent angle of a quadratic Bezier curve.
func quadAngle(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGFloat {
    let dx = 2 * (1 - t) * (c.x - p0.x) + 2 * t * (p1.x - c.x)
    let dy = 2 * (1 - t) * (c.y - p0.y) + 2 * t * (p1.y - c.y)
    return atan2(dy, dx)
}

// MARK: - Drawing

func drawBackground(in ctx: CGContext, scale: CGFloat) {
    ctx.scaleBy(x: scale, y: scale)

    let cream = rgb(0xFFF6EA)
    let tomato = rgb(0xE8402F)
    let tomatoDark = rgb(0xC9322A)

    // Warm cream paper with a gentle vertical gradient.
    ctx.setFillColor(cream)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.drawLinearGradient(
        gradient([rgb(0xFFFBF4), rgb(0xFFF1DC), rgb(0xFFE6CC)], [0, 0.6, 1]),
        start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: []
    )
    // Soft tomato glows behind the two icon slots.
    for cx in [CGFloat(165), CGFloat(495)] {
        ctx.drawRadialGradient(
            gradient([rgb(0xFFB199, 0.40), rgb(0xFFB199, 0)], [0, 1]),
            startCenter: CGPoint(x: cx, y: 200), startRadius: 0,
            endCenter: CGPoint(x: cx, y: 200), endRadius: 120, options: []
        )
    }

    // A tomato band at the top, with a wavy lower edge.
    let band = CGMutablePath()
    band.move(to: CGPoint(x: 0, y: height))
    band.addLine(to: CGPoint(x: 0, y: 344))
    let waves = 6
    let waveWidth = width / CGFloat(waves)
    for i in 0..<waves {
        let x0 = CGFloat(i) * waveWidth
        band.addQuadCurve(to: CGPoint(x: x0 + waveWidth, y: 344),
                          control: CGPoint(x: x0 + waveWidth / 2, y: i % 2 == 0 ? 334 : 354))
    }
    band.addLine(to: CGPoint(x: width, y: height))
    band.closeSubpath()
    ctx.saveGState()
    ctx.addPath(band)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFF7A5C), rgb(0xF04A36), rgb(0xD62F25)], [0, 0.6, 1]),
        start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 330), options: []
    )
    ctx.restoreGState()

    // Title on the band.
    let titleFont = font(["SFProRounded-Bold", "ArialRoundedMTBold", "HelveticaNeue-Bold"], size: 24)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -1 * scale), blur: 3 * scale, color: rgb(0x7A1410, 0.45))
    drawCenteredText("Trascina il gatto nelle Applicazioni", in: ctx, font: titleFont,
                     color: rgb(0xFFFFFF), centerX: width / 2, baselineY: 360)
    ctx.restoreGState()

    // Paw print trail walking from the app slot to Applications, under
    // the arrow, alternating left and right feet.
    let trailStart = CGPoint(x: 240, y: 150)
    let trailControl = CGPoint(x: 330, y: 118)
    let trailEnd = CGPoint(x: 420, y: 150)
    let steps = 6
    for i in 0..<steps {
        let t = (CGFloat(i) + 0.5) / CGFloat(steps)
        let p = quadPoint(trailStart, trailControl, trailEnd, t)
        let a = quadAngle(trailStart, trailControl, trailEnd, t)
        let side: CGFloat = i % 2 == 0 ? 1 : -1
        let offset = CGPoint(x: -sin(a) * 7 * side, y: cos(a) * 7 * side)
        let alpha = 0.30 + 0.45 * t
        drawPaw(in: ctx, center: CGPoint(x: p.x + offset.x, y: p.y + offset.y),
                angle: a, size: 15, color: rgb(0xDB7A2E, alpha))
    }

    // A friendly hand-drawn arrow arcing from the app to Applications.
    let arrowStart = CGPoint(x: 250, y: 212)
    let arrowControl = CGPoint(x: 330, y: 262)
    let arrowEnd = CGPoint(x: 404, y: 214)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -2 * scale), blur: 4 * scale, color: rgb(0x7A1410, 0.25))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setStrokeColor(tomato)
    ctx.setLineWidth(9)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: arrowStart)
    ctx.addQuadCurve(to: arrowEnd, control: arrowControl)
    ctx.strokePath()
    // Arrow head, aligned with the end tangent.
    let endAngle = quadAngle(arrowStart, arrowControl, arrowEnd, 1)
    let headLength: CGFloat = 26
    let spread: CGFloat = 0.62
    let left = CGPoint(x: arrowEnd.x - headLength * cos(endAngle - spread),
                       y: arrowEnd.y - headLength * sin(endAngle - spread))
    let right = CGPoint(x: arrowEnd.x - headLength * cos(endAngle + spread),
                        y: arrowEnd.y - headLength * sin(endAngle + spread))
    ctx.move(to: left)
    ctx.addLine(to: arrowEnd)
    ctx.addLine(to: right)
    ctx.strokePath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Highlight along the arrow, like the shine on the icon's tomato.
    ctx.setStrokeColor(rgb(0xFFB199, 0.7))
    ctx.setLineWidth(2.5)
    ctx.setLineCap(.round)
    let hlStart = quadPoint(arrowStart, arrowControl, arrowEnd, 0.12)
    let hlEnd = quadPoint(arrowStart, arrowControl, arrowEnd, 0.42)
    let hlControl = quadPoint(arrowStart, arrowControl, arrowEnd, 0.27)
    ctx.move(to: CGPoint(x: hlStart.x, y: hlStart.y + 2))
    ctx.addQuadCurve(to: CGPoint(x: hlEnd.x, y: hlEnd.y + 2),
                     control: CGPoint(x: hlControl.x, y: hlControl.y + 6))
    ctx.strokePath()

    // A tiny tomato with its calyx at the top of the arc.
    let tomatoCenter = CGPoint(x: 330, y: 268)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -1 * scale), blur: 3 * scale, color: rgb(0x7A1410, 0.3))
    ctx.setFillColor(tomatoDark)
    ctx.addPath(ellipse(tomatoCenter.x, tomatoCenter.y, 13, 11))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFFFFF, 0.35))
    ctx.addPath(ellipse(tomatoCenter.x - 5, tomatoCenter.y + 4, 4, 2.5))
    ctx.fillPath()
    ctx.setFillColor(rgb(0x3FA34D))
    for angle in [CGFloat(20), CGFloat(90), CGFloat(160)] {
        let r = angle * CGFloat.pi / 180
        ctx.addPath(ellipse(tomatoCenter.x + cos(r) * 5, tomatoCenter.y + 9 + sin(r) * 2, 4.5, 2.2))
    }
    ctx.fillPath()

    // Small paws in the corners as decoration.
    drawPaw(in: ctx, center: CGPoint(x: 44, y: 70), angle: 1.2, size: 14, color: rgb(0xF6A04D, 0.35))
    drawPaw(in: ctx, center: CGPoint(x: 616, y: 78), angle: 1.9, size: 14, color: rgb(0xF6A04D, 0.35))

    // Footer.
    let footerFont = font(["SFProRounded-Medium", "ArialRoundedMTBold", "HelveticaNeue-Medium"], size: 12)
    drawCenteredText("Maramao · il Pomodoro che ti ferma coi gatti", in: ctx, font: footerFont,
                     color: rgb(0x3A2420, 0.6), centerX: width / 2, baselineY: 42)
}

// MARK: - Output

func renderPNG(scale: CGFloat, to url: URL) -> Bool {
    let pixelWidth = Int(width * scale)
    let pixelHeight = Int(height * scale)
    guard let ctx = CGContext(
        data: nil, width: pixelWidth, height: pixelHeight,
        bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    drawBackground(in: ctx, scale: scale)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    // 72 dpi per point, so the @2x image is 144 dpi and tiffutil pairs them.
    let dpi = 72 * scale
    let properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi,
        kCGImagePropertyDPIHeight: dpi,
    ]
    CGImageDestinationAddImage(dest, image, properties as CFDictionary)
    return CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: swift make-dmg-background.swift <out-dir>\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
do {
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write("make-dmg-background: cannot create \(outDir.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}

var failed = false
for (scale, name) in [(CGFloat(1), "background.png"), (CGFloat(2), "background@2x.png")] {
    let url = outDir.appendingPathComponent(name)
    if renderPNG(scale: scale, to: url) {
        print("make-dmg-background: wrote \(name) (\(Int(width * scale))x\(Int(height * scale)))")
    } else {
        FileHandle.standardError.write("make-dmg-background: failed to write \(name)\n".data(using: .utf8)!)
        failed = true
    }
}
exit(failed ? 1 : 0)
