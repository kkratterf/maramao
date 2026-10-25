import SwiftUI

/// A minimal break screen: dimmed background, a sitting cat and the countdown.
/// Used by modes that are still being built.
struct PlaceholderCurtain: View {
    let context: BreakContext

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            VStack(spacing: 24) {
                CatView(pose: .sitting, palette: .orange)
                    .frame(width: 240, height: 192)
                BreakHUD(context: context)
            }
        }
        .ignoresSafeArea()
    }
}
