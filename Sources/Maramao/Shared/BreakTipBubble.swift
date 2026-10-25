import SwiftUI
import MaramaoCore

/// Hands out one tip per break, never the same as the previous break's.
@MainActor
final class BreakTipStore {
    static let shared = BreakTipStore()

    private var picker = BreakTipPicker()
    private var packGeneration = 0

    func nextTip(isLongBreak: Bool) -> String {
        // Cat packs can add tips and cat names; rebuild the picker when they change.
        let packs = CatPackRuntime.shared.content
        if packs.generation != packGeneration {
            packGeneration = packs.generation
            picker = BreakTipPicker(
                shortTips: BreakTips.short + packs.shortTips,
                longTips: BreakTips.long + packs.longTips,
                last: picker.last
            )
        }
        let tip = picker.next(isLongBreak: isLongBreak)
        guard !tip.isEmpty, let name = packs.catNames.randomElement() else { return tip }
        return String(localized: "\(name) dice: \(tip)")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Consiglio del gatto: \(text)"))
    }

    @Environment(\.colorSchemeContrast) private var contrast

    private var fill: Color {
        let solid = contrast == .increased
        return style == .dark ? Color.white.opacity(solid ? 1 : 0.92) : Color(white: 0.12).opacity(solid ? 1 : 0.88)
    }
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
