import SwiftUI
import MaramaoCore

/// The countdown pill every break mode shows: a paw, the remaining time and, when
/// allowed, the close button. Nothing else: no captions, no tips.
struct BreakHUD: View {
    let context: BreakContext
    var style: Style = .dark

    enum Style { case dark, light }

    var body: some View {
        // Redraws once a second, right after the countdown text changes (it counts down to
        // `endDate`), instead of polling: the HUD sits on every screen for the whole break.
        TimelineView(.periodic(from: clockTickStart, by: 1)) { _ in
            HStack(spacing: 12) {
                Text("🐾")
                    .font(.system(size: 20))
                    .accessibilityHidden(true)
                Text(formatClock(context.remaining))
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .accessibilityLabel("Tempo rimanente")
                    .accessibilityValue(BreakSpeech.countdownValue(remaining: context.remaining))
                if context.canSkipNow {
                    Button {
                        context.requestSkip()
                    } label: {
                        Text("Chiudi")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(skipBackground)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(context.isPreview ? LocalizedStringKey("Chiudi l'anteprima") : LocalizedStringKey("Salta la pausa"))
                    .accessibilityHint(skipHint)
                    .help(skipHint)
                } else if context.skipUnlockDate == nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .opacity(isHighContrast ? 1 : 0.6)
                        .help("Modalità severa: la pausa non si salta")
                        .accessibilityLabel("Modalità severa: la pausa non si salta")
                }
            }
            .foregroundStyle(foreground)
            .padding(.leading, 18)
            .padding(.trailing, context.canSkipNow ? 8 : 18)
            .padding(.vertical, 8)
            .background(pillBackground)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .accessibilityElement(children: .contain)
            // Own key: "Pausa" alone is the menu's "Pause" button.
            .accessibilityLabel(String(localized: "hud.accessibility.break", defaultValue: "Pausa"))
            .accessibilityHint(context.canSkipNow ? "" : skipHint)
        }
    }

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Increase Contrast or Reduce Transparency: solid background, outlined, full-opacity text.
    private var isHighContrast: Bool { contrast == .increased || reduceTransparency }

    @ViewBuilder
    private var pillBackground: some View {
        if isHighContrast {
            Capsule()
                .fill(background)
                .overlay(Capsule().stroke(foreground.opacity(0.8), lineWidth: 1.5))
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(background.opacity(0.55)))
        }
    }

    @ViewBuilder
    private var skipBackground: some View {
        if isHighContrast {
            Capsule()
                .fill(foreground.opacity(0.25))
                .overlay(Capsule().stroke(foreground, lineWidth: 1))
        } else {
            Capsule().fill(foreground.opacity(0.15))
        }
    }

    private var skipHint: String {
        let wait = context.skipUnlockDate.map { max(0, Int($0.timeIntervalSinceNow.rounded(.up))) }
        return BreakSpeech.skipHint(secondsUntilUnlock: wait, shortcut: BreakAccessibility.skipShortcutLabel)
    }

    /// A moment when the clock text has just changed: the countdown flips on whole seconds
    /// before `endDate`.
    private var clockTickStart: Date {
        context.endDate.addingTimeInterval(0.01 - context.duration.rounded(.up))
    }

    private var foreground: Color { style == .dark ? .white : .black }
    private var background: Color { style == .dark ? .black : .white }
}
