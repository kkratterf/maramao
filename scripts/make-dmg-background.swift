// Draws the background of the Maramao DMG window with CoreGraphics and
// CoreText, in the same palette as the app icon (scripts/make-icon.swift).
// Usage: swift scripts/make-dmg-background.swift <out-dir>
// Writes <out-dir>/background.png (440x588) and background@2x.png
// (880x1176). Combine them with:
//   tiffutil -cathidpicheck background.png background@2x.png -out background.tiff
//
// A tall window, top to bottom: a dark keyboard where Maramao.app sits as
// the glowing M key (⌃⌥⌘M starts a pomodoro), then a lighter panel with
// chevrons pointing down to the Applications folder.
//
// The design space is 440x588 points, origin bottom-left. Finder places
// the icons (top-left origin) with Maramao.app centred at (220, 196) and
// Applications at (220, 430): `top(y)` converts those Finder coordinates.
// Finder's window bounds include the title bar, so the bottom ~28 points
// may be hidden: nothing important is drawn there.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

let width: CGFloat = 440
let height: CGFloat = 588

/// Finder (top-left origin) y to CoreGraphics (bottom-left origin) y.
func top(_ y: CGFloat) -> CGFloat { height - y }

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

// MARK: - Drawing

let appCenter = CGPoint(x: 220, y: top(196))
/// Where the dark keyboard ends and the light panel starts, just under the
/// app icon so Finder's "Maramao" label sits on the light part.
let panelTop = top(266)

let legendColor = rgb(0xB7A7AC, 0.85)
let legendFont = font(["SFPro-Regular", "HelveticaNeue", "Helvetica"], size: 17)

/// Shadow offsets and blurs are in pixels, not points: multiply by this.
var pixelScale: CGFloat = 1

/// A dark keyboard key cap with a soft top highlight. `centered` draws a
/// big legend in the middle, like a letter key.
func drawKey(in ctx: CGContext, rect: CGRect, centered: String = "") {
    let cap = CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -3 * pixelScale), blur: 6 * pixelScale, color: rgb(0x000000, 0.5))
    ctx.addPath(cap)
    ctx.setFillColor(rgb(0x221A1D))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(cap)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0x2E2427), rgb(0x1E1719)], [0, 1]),
        start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: []
    )
    ctx.restoreGState()
    ctx.addPath(cap)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.07))
    ctx.setLineWidth(1)
    ctx.strokePath()
    if !centered.isEmpty {
        let big = font(["SFPro-Regular", "HelveticaNeue-Light", "Helvetica"], size: 38)
        drawCenteredText(centered, in: ctx, font: big, color: legendColor, centerX: rect.midX, baselineY: rect.midY - 13)
    }
}

/// One line of text starting at `x`, or ending at `rightX`.
func drawText(_ text: String, in ctx: CGContext, font: CTFont, color: CGColor,
              x: CGFloat? = nil, rightX: CGFloat? = nil, baselineY: CGFloat) {
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes) as CFAttributedString)
    let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: x ?? ((rightX ?? 0) - lineWidth), y: baselineY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

/// A downward chevron centred at `center`.
func drawChevron(in ctx: CGContext, center: CGPoint, color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: center.x - 15, y: center.y + 7))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y - 7))
    ctx.addLine(to: CGPoint(x: center.x + 15, y: center.y + 7))
    ctx.strokePath()
}

func drawBackground(in ctx: CGContext, scale: CGFloat) {
    pixelScale = scale
    ctx.scaleBy(x: scale, y: scale)

    // The keyboard: warm near-black with a tomato glow behind the app key.
    ctx.setFillColor(rgb(0x140F11))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.drawRadialGradient(
        gradient([rgb(0xE8402F, 0.38), rgb(0xE8402F, 0.10), rgb(0xE8402F, 0)], [0, 0.45, 1]),
        startCenter: appCenter, startRadius: 0, endCenter: appCenter, endRadius: 260, options: []
    )

    // Top row, cut by the window edges like a close-up of a real keyboard:
    // it spells MIAO.
    let keySize: CGFloat = 104
    let gap: CGFloat = 14
    let rowWidth = 4 * keySize + 3 * gap
    for (i, letter) in ["M", "I", "A", "O"].enumerated() {
        let x = (width - rowWidth) / 2 + CGFloat(i) * (keySize + gap)
        drawKey(in: ctx, rect: CGRect(x: x, y: top(106), width: keySize, height: keySize), centered: letter)
    }

    // Middle row, sinking into the panel below: the app as M in the middle,
    // between command and option, like a hand reaching for ⌃⌥⌘M.
    let slot: CGFloat = 144
    let ring = CGRect(x: appCenter.x - slot / 2, y: appCenter.y - slot / 2, width: slot, height: slot)
    let sideWidth: CGFloat = 130
    let sideBottom = panelTop - 30
    let sideTop = ring.maxY
    let commandKey = CGRect(x: ring.minX - gap - sideWidth, y: sideBottom, width: sideWidth, height: sideTop - sideBottom)
    let optionKey = CGRect(x: ring.maxX + gap, y: sideBottom, width: sideWidth, height: sideTop - sideBottom)
    drawKey(in: ctx, rect: commandKey)
    drawKey(in: ctx, rect: optionKey)
    // Legends as printed on Apple keyboards: the symbol in the top corner,
    // the name in the bottom one.
    drawText("⌘", in: ctx, font: legendFont, color: legendColor, rightX: commandKey.maxX - 16, baselineY: commandKey.maxY - 32)
    drawText("command", in: ctx, font: legendFont, color: legendColor, x: commandKey.minX + 16, baselineY: panelTop + 18)
    drawText("⌥", in: ctx, font: legendFont, color: legendColor, x: optionKey.minX + 16, baselineY: optionKey.maxY - 32)
    drawText("option", in: ctx, font: legendFont, color: legendColor, rightX: optionKey.maxX - 16, baselineY: panelTop + 18)

    // The app key: a glowing tomato ring around Finder's 128 pt icon.
    let ringPath = CGPath(roundedRect: ring, cornerWidth: 34, cornerHeight: 34, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 22 * pixelScale, color: rgb(0xFF5A40, 0.85))
    ctx.addPath(ringPath)
    ctx.setFillColor(rgb(0x241B1E))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(ringPath)
    ctx.setStrokeColor(rgb(0xFF7A5C))
    ctx.setLineWidth(3)
    ctx.strokePath()

    // The light panel, with a soft edge so the keyboard seems to sink into it.
    let panel = CGRect(x: 0, y: 0, width: width, height: panelTop)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 6 * pixelScale), blur: 18 * pixelScale, color: rgb(0x000000, 0.55))
    ctx.setFillColor(rgb(0xA79C98))
    ctx.fill(panel)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.clip(to: panel)
    ctx.drawLinearGradient(
        gradient([rgb(0xB7ADA9), rgb(0x8E8582), rgb(0x6F6764)], [0, 0.55, 1]),
        start: CGPoint(x: 0, y: panelTop), end: CGPoint(x: 0, y: 0), options: []
    )
    // The app key's glow spills over the edge of the panel.
    ctx.drawRadialGradient(
        gradient([rgb(0xE8402F, 0.22), rgb(0xE8402F, 0)], [0, 1]),
        startCenter: CGPoint(x: appCenter.x, y: panelTop), startRadius: 0,
        endCenter: CGPoint(x: appCenter.x, y: panelTop), endRadius: 200, options: []
    )
    ctx.restoreGState()
    // The panel's edge, like the light catching the front of the keyboard.
    ctx.setFillColor(rgb(0xFFFFFF, 0.18))
    ctx.fill(CGRect(x: 0, y: panelTop - 1, width: width, height: 1))

    // Three chevrons pointing from the app down to Applications, brighter
    // towards the folder.
    let chevronTop = top(318)
    for i in 0..<3 {
        let alpha = 0.35 + 0.3 * CGFloat(i)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 8 * pixelScale, color: rgb(0xFF7A5C, alpha * 0.8))
        drawChevron(in: ctx, center: CGPoint(x: appCenter.x, y: chevronTop - CGFloat(i) * 15),
                    color: rgb(0xFFE3DA, alpha))
        ctx.restoreGState()
    }

    // Faint paw prints wandering around the folder.
    drawPaw(in: ctx, center: CGPoint(x: 66, y: top(470)), angle: 1.35, size: 16, color: rgb(0xFFFFFF, 0.12))
    drawPaw(in: ctx, center: CGPoint(x: 84, y: top(430)), angle: 1.75, size: 16, color: rgb(0xFFFFFF, 0.16))
    drawPaw(in: ctx, center: CGPoint(x: 374, y: top(410)), angle: 1.4, size: 16, color: rgb(0xFFFFFF, 0.12))
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
