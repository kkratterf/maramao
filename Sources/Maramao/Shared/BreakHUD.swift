import SwiftUI
import MaramaoCore

/// The countdown pill every break mode shows: remaining time, a line of text and,
/// when allowed, the skip button.
struct BreakHUD: View {
    let context: BreakContext
    var message: String = "Pausa. Il gatto ha deciso."
    var style: Style = .dark

    enum Style { case dark, light }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            HStack(spacing: 14) {
                Text("🐾")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatClock(context.remaining))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.8)
                }
                if context.canSkipNow {
                    Button {
                        context.requestSkip()
                    } label: {
                        Text(context.isPreview ? "Chiudi" : "Salta")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(foreground.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                } else if context.skipUnlockDate == nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .opacity(0.6)
                        .help("Modalità severa: la pausa non si salta")
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(background.opacity(0.55)))
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
    }

    private var foreground: Color { style == .dark ? .white : .black }
    private var background: Color { style == .dark ? .black : .white }
}
