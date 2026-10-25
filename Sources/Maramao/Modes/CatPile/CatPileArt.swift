import AppKit
import SwiftUI

/// One pre-rendered cat image, cropped to the area the cat actually covers.
struct CatPileArtwork {
    let image: CGImage
    /// Height divided by width of the cropped cat.
    let aspect: CGFloat
}

/// Renders `CatView` poses and palettes to bitmaps once per break, so the
/// SpriteKit scene never renders SwiftUI per frame.
@MainActor
enum CatPileArt {
    /// Render size of the 200×160 design space, in points. Large enough for the biggest cats.
    private static let designScale: CGFloat = 1.6

    private struct Variant {
        let pose: CatPose
        let eyesClosed: Bool
        /// The part of the 200×160 design space (y down) the pose covers.
        let content: CGRect
    }

    private static let variants: [Variant] = [
        Variant(pose: .sitting, eyesClosed: false, content: CGRect(x: 50, y: 16, width: 112, height: 144)),
        Variant(pose: .sitting, eyesClosed: true, content: CGRect(x: 50, y: 16, width: 112, height: 144)),
        Variant(pose: .sleeping, eyesClosed: true, content: CGRect(x: 28, y: 84, width: 152, height: 76)),
        Variant(pose: .stretching, eyesClosed: false, content: CGRect(x: 12, y: 14, width: 176, height: 142)),
        Variant(pose: .walking(step: 0.8), eyesClosed: false, content: CGRect(x: 6, y: 26, width: 188, height: 132)),
    ]

    /// Renders every pose in every palette at the given backing scale.
    static func render(scale: CGFloat) -> [CatPileArtwork] {
        let renderWidth = 200 * designScale
        let renderHeight = 160 * designScale
        var result: [CatPileArtwork] = []
        for palette in CatPalette.all {
            for variant in variants {
                let view = CatView(pose: variant.pose, palette: palette, eyesClosed: variant.eyesClosed)
                    .frame(width: renderWidth, height: renderHeight)
                let renderer = ImageRenderer(content: view)
                renderer.scale = scale
                guard let full = renderer.cgImage else { continue }
                // CGImage cropping uses pixel coordinates with the origin at the top left,
                // which matches the design space of CatView.
                let factor = designScale * scale
                let crop = CGRect(
                    x: variant.content.minX * factor,
                    y: variant.content.minY * factor,
                    width: variant.content.width * factor,
                    height: variant.content.height * factor
                ).integral.intersection(CGRect(x: 0, y: 0, width: full.width, height: full.height))
                let image = full.cropping(to: crop) ?? full
                let aspect = CGFloat(image.height) / max(1, CGFloat(image.width))
                result.append(CatPileArtwork(image: image, aspect: aspect))
            }
        }
        return result
    }
}
