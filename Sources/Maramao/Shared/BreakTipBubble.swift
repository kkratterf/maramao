import SwiftUI
import MaramaoCore

/// Hands out one tip per break, never the same as the previous break's.
@MainActor
final class BreakTipStore {
    static let shared = BreakTipStore()

    private var picker = BreakTipPicker()

    func nextTip(isLongBreak: Bool) -> String {
        picker.next(isLongBreak: isLongBreak)
    }
}

/// A small speech bubble with the cat's suggestion for the break, shown under the HUD.
struct BreakTipBubble: View {
    let text: String
    var style: BreakHUD.Style = .dark

    var body: some View {
        VStack(spacing: 0) {
            BreakTipBubbleTail()
                .fill(fill)
                .frame(width: 16, height: 8)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("🐱")
                    .font(.system(size: 15))
                Text(text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: 440)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
        }
        .fixedSize(horizontal: false, vertical: true)
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
        .allowsHitTesting(false)
    }

    private var fill: Color { style == .dark ? Color.white.opacity(0.92) : Color(white: 0.12).opacity(0.88) }
    private var textColor: Color { style == .dark ? Color(white: 0.12) : .white }
}

/// The bubble's tail, pointing up towards the HUD.
struct BreakTipBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
