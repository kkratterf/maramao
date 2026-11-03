import AppKit
import SwiftUI

/// The full-screen backdrop behind a break, like the dimmed, blurred desktop behind a modal
/// on the Mac: whatever is on screen stays faintly visible, blurred and darkened, so the cats
/// stand out without a coloured tint.
///
/// Reduce Transparency or Increase Contrast: a solid, nearly black backdrop instead.
struct ModalBackdrop: View {
    /// How dark the blur gets, 0...1.
    var dim: Double = 0.45

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if contrast == .increased || reduceTransparency {
            Color.black.opacity(0.96)
        } else {
            ZStack {
                BehindWindowBlur()
                Color.black.opacity(dim)
            }
        }
    }
}

/// An `NSVisualEffectView` that blurs what is behind the window (other apps, the desktop).
private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
