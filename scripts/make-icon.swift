// Draws the Maramao app icon with CoreGraphics and writes a full .iconset.
// Usage: swift scripts/make-icon.swift <out.iconset>
// Then:  iconutil -c icns <out.iconset> -o AppIcon.icns
//
// Everything is drawn in a 1024x1024 design space (origin bottom-left) and
// scaled for each size, so the output is deterministic and needs no assets.

import CoreGraphics
import Foundation
import ImageIO

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

/// Superellipse ("squircle") close to the Big Sur icon shape.
func squircle(center: CGPoint, radius: CGFloat, exponent: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let steps = 720
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * CGFloat.pi
        let c = cos(t)
        let s = sin(t)
        let x = center.x + radius * (c < 0 ? -1 : 1) * pow(abs(c), 2 / exponent)
        let y = center.y + radius * (s < 0 ? -1 : 1) * pow(abs(s), 2 / exponent)
        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    path.closeSubpath()
    return path
}

/// An ear: a triangle with a rounded tip.
func ear(baseA: CGPoint, tip: CGPoint, baseB: CGPoint) -> CGPath {
    let path = CGMutablePath()
    path.move(to: baseA)
    let nearTipA = CGPoint(x: tip.x + (baseA.x - tip.x) * 0.18, y: tip.y + (baseA.y - tip.y) * 0.18)
    let nearTipB = CGPoint(x: tip.x + (baseB.x - tip.x) * 0.18, y: tip.y + (baseB.y - tip.y) * 0.18)
    path.addLine(to: nearTipA)
    path.addQuadCurve(to: nearTipB, control: tip)
    path.addLine(to: baseB)
    path.closeSubpath()
    return path
}

/// A pointed leaf lying along +x from the origin, rotated and moved.
func leaf(at origin: CGPoint, angleDegrees: CGFloat, length: CGFloat, width: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: .zero)
    path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.45, y: width))
    path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.45, y: -width))
    path.closeSubpath()
    var transform = CGAffineTransform(translationX: origin.x, y: origin.y)
        .rotated(by: angleDegrees * CGFloat.pi / 180)
    return path.copy(using: &transform) ?? path
}

func mirrored(_ p: CGPoint) -> CGPoint {
    return CGPoint(x: 1024 - p.x, y: p.y)
}

// MARK: - Drawing

func drawIcon(in ctx: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)

    // Apple's template: an 824pt shape centred on a 1024pt canvas.
    let shape = squircle(center: CGPoint(x: 512, y: 512), radius: 412, exponent: 5)

    // Drop shadow under the tile. Shadow metrics are in device space.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 24 * scale, color: rgb(0x000000, 0.30))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(0xE8402F))
    ctx.fillPath()
    ctx.restoreGState()

    // Everything else lives inside the tile.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // Warm tomato gradient.
    ctx.drawLinearGradient(
        gradient([rgb(0xFF7A5C), rgb(0xF04A36), rgb(0xD62F25)], [0, 0.55, 1]),
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: []
    )
    // Soft glow in the upper half.
    ctx.drawRadialGradient(
        gradient([rgb(0xFFB199, 0.55), rgb(0xFFB199, 0)], [0, 1]),
        startCenter: CGPoint(x: 512, y: 760), startRadius: 0,
        endCenter: CGPoint(x: 512, y: 760), endRadius: 420, options: []
    )
    // Tomato shine, top left.
    ctx.saveGState()
    ctx.translateBy(x: 330, y: 790)
    ctx.rotate(by: 0.55)
    ctx.addPath(ellipse(0, 0, 120, 52))
    ctx.setFillColor(rgb(0xFFFFFF, 0.22))
    ctx.fillPath()
    ctx.addPath(ellipse(150, -10, 26, 22))
    ctx.fillPath()
    ctx.restoreGState()

    drawCat(in: ctx, scale: scale)

    ctx.restoreGState()
}

func drawCat(in ctx: CGContext, scale: CGFloat) {
    let orange = rgb(0xF6A04D)
    let orangeDark = rgb(0xDB7A2E)
    let cream = rgb(0xFFF1DC)
    let pink = rgb(0xF7A8A0)
    let ink = rgb(0x3A2420)

    let headCX: CGFloat = 512
    let headCY: CGFloat = 300
    let head = ellipse(headCX, headCY, 305, 245)

    let leftEar = ear(baseA: CGPoint(x: 236, y: 410), tip: CGPoint(x: 262, y: 700), baseB: CGPoint(x: 430, y: 535))
    let leftInner = ear(baseA: CGPoint(x: 280, y: 455), tip: CGPoint(x: 292, y: 640), baseB: CGPoint(x: 400, y: 525))
    let rightEar = ear(baseA: mirrored(CGPoint(x: 236, y: 410)), tip: mirrored(CGPoint(x: 262, y: 700)), baseB: mirrored(CGPoint(x: 430, y: 535)))
    let rightInner = ear(baseA: mirrored(CGPoint(x: 280, y: 455)), tip: mirrored(CGPoint(x: 292, y: 640)), baseB: mirrored(CGPoint(x: 400, y: 525)))

    // Silhouette with a soft shadow, drawn as one group.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 30 * scale, color: rgb(0x7A1410, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(orange)
    ctx.addPath(leftEar)
    ctx.addPath(rightEar)
    ctx.addPath(head)
    ctx.fillPath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Head shading: lighter on top.
    ctx.saveGState()
    ctx.addPath(head)
    ctx.addPath(leftEar)
    ctx.addPath(rightEar)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFC27A), rgb(0xF6A04D), rgb(0xE98A3A)], [0, 0.5, 1]),
        start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 80), options: []
    )
    ctx.restoreGState()

    // Inner ears.
    ctx.setFillColor(pink)
    ctx.addPath(leftInner)
    ctx.addPath(rightInner)
    ctx.fillPath()

    // Tabby stripes on the forehead.
    ctx.setStrokeColor(orangeDark)
    ctx.setLineCap(.round)
    ctx.setLineWidth(20)
    ctx.move(to: CGPoint(x: 432, y: 498)); ctx.addLine(to: CGPoint(x: 446, y: 455))
    ctx.move(to: CGPoint(x: 592, y: 498)); ctx.addLine(to: CGPoint(x: 578, y: 455))
    ctx.move(to: CGPoint(x: 512, y: 488)); ctx.addLine(to: CGPoint(x: 512, y: 448))
    ctx.strokePath()

    // Cream muzzle and chin.
    ctx.setFillColor(cream)
    ctx.addPath(ellipse(512, 235, 200, 130))
    ctx.fillPath()

    // Cheek blush.
    ctx.setFillColor(rgb(0xF27A7A, 0.45))
    ctx.addPath(ellipse(330, 300, 40, 24))
    ctx.addPath(ellipse(694, 300, 40, 24))
    ctx.fillPath()

    // Eyes with highlights.
    for cx in [CGFloat(398), CGFloat(626)] {
        ctx.setFillColor(ink)
        ctx.addPath(ellipse(cx, 378, 44, 54))
        ctx.fillPath()
        ctx.setFillColor(rgb(0xFFFFFF))
        ctx.addPath(ellipse(cx + 14, 398, 15, 15))
        ctx.fillPath()
        ctx.addPath(ellipse(cx - 13, 360, 7, 7))
        ctx.fillPath()
    }

    // Nose.
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: 484, y: 322))
    nose.addQuadCurve(to: CGPoint(x: 540, y: 322), control: CGPoint(x: 512, y: 334))
    nose.addQuadCurve(to: CGPoint(x: 512, y: 294), control: CGPoint(x: 532, y: 300))
    nose.addQuadCurve(to: CGPoint(x: 484, y: 322), control: CGPoint(x: 492, y: 300))
    nose.closeSubpath()
    ctx.setFillColor(rgb(0xEE6F7A))
    ctx.addPath(nose)
    ctx.fillPath()

    // Mouth: a little "w".
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(9)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 512, y: 296))
    ctx.addLine(to: CGPoint(x: 512, y: 276))
    ctx.move(to: CGPoint(x: 462, y: 284))
    ctx.addQuadCurve(to: CGPoint(x: 512, y: 276), control: CGPoint(x: 484, y: 250))
    ctx.addQuadCurve(to: CGPoint(x: 562, y: 284), control: CGPoint(x: 540, y: 250))
    ctx.strokePath()

    // Whiskers.
    ctx.setStrokeColor(rgb(0x5A3328, 0.75))
    ctx.setLineWidth(7)
    let whiskers: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 330, y: 262), CGPoint(x: 168, y: 292)),
        (CGPoint(x: 330, y: 246), CGPoint(x: 162, y: 246)),
        (CGPoint(x: 334, y: 230), CGPoint(x: 176, y: 196)),
    ]
    for (a, b) in whiskers {
        ctx.move(to: a); ctx.addLine(to: b)
        ctx.move(to: mirrored(a)); ctx.addLine(to: mirrored(b))
    }
    ctx.strokePath()

    // Tomato calyx on the head: five green leaves and a stem.
    let calyx = CGPoint(x: 512, y: 548)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 8 * scale, color: rgb(0x5A2A10, 0.35))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(rgb(0x3FA34D))
    for angle in [CGFloat(54), CGFloat(126), CGFloat(198), CGFloat(342), CGFloat(-90)] {
        ctx.addPath(leaf(at: calyx, angleDegrees: angle, length: angle == -90 ? 70 : 92, width: 26))
    }
    ctx.addPath(ellipse(calyx.x, calyx.y, 24, 20))
    ctx.fillPath()
    // Stem, curving slightly to the right.
    ctx.setStrokeColor(rgb(0x2E8B3E))
    ctx.setLineWidth(18)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: calyx.x, y: calyx.y + 6))
    ctx.addQuadCurve(to: CGPoint(x: calyx.x + 22, y: calyx.y + 74), control: CGPoint(x: calyx.x - 4, y: calyx.y + 50))
    ctx.strokePath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Leaf veins/highlight.
    ctx.setStrokeColor(rgb(0x7BD27F, 0.8))
    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    for angle in [CGFloat(54), CGFloat(126), CGFloat(198), CGFloat(342)] {
        let r = angle * CGFloat.pi / 180
        ctx.move(to: CGPoint(x: calyx.x + cos(r) * 22, y: calyx.y + sin(r) * 22))
        ctx.addLine(to: CGPoint(x: calyx.x + cos(r) * 62, y: calyx.y + sin(r) * 62))
    }
    ctx.strokePath()
}

// MARK: - Output

func renderPNG(pixels: Int, to url: URL) -> Bool {
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return false }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    drawIcon(in: ctx, pixels: pixels)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: swift make-icon.swift <out.iconset>\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.removeItem(at: outDir)
do {
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
} catch {
    FileHandle.standardError.write("make-icon: cannot create \(outDir.path): \(error)\n".data(using: .utf8)!)
    exit(1)
}

// (point size, scale) pairs required by iconutil.
let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
var failed = false
for (points, factor) in variants {
    let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    let url = outDir.appendingPathComponent(name)
    if renderPNG(pixels: points * factor, to: url) {
        print("make-icon: wrote \(name) (\(points * factor)px)")
    } else {
        FileHandle.standardError.write("make-icon: failed to write \(name)\n".data(using: .utf8)!)
        failed = true
    }
}
exit(failed ? 1 : 0)
