import SwiftUI
import MaramaoCore

/// The countdown pill every break mode shows: remaining time, a line of text and,
/// when allowed, the skip button.
struct BreakHUD: View {
    let context: BreakContext
    var message: String = String(localized: "Pausa. Il gatto ha deciso.")
    var style: Style = .dark

    /// Shows the cat's break tip under the pill when there is room for it.
    var showsTip = true

    enum Style { case dark, light }

    var body: some View {
        // The tip only appears where it fits: modes that host the HUD in a small window keep the pill alone.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 6) {
                pill
                if showsTip { BreakTipBubble(text: context.tip, style: style) }
            }
            pill
        }
    }

    private var pill: some View {
        // Redraws once a second, right after the countdown text changes (it counts down to
        // `endDate`), instead of polling: the HUD sits on every screen for the whole break.
        TimelineView(.periodic(from: clockTickStart, by: 1)) { _ in
            HStack(spacing: 14) {
                Text("🐾")
                    .font(.system(size: 22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatClock(context.remaining))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .accessibilityLabel("Tempo rimanente")
                        .accessibilityValue(BreakSpeech.countdownValue(remaining: context.remaining))
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(isHighContrast ? 1 : 0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Long messages wrap instead of pushing the buttons out of small HUD windows.
                .frame(maxWidth: 240, alignment: .leading)
                if context.canSnoozeNow {
                    VStack(spacing: 3) {
                        Button {
                            context.requestSnooze()
                        } label: {
                            Text(BreakSnoozeText.button(minutes: context.snoozeMinutes))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(skipBackground)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(BreakSnoozeText.left(context.snoozesLeft))
                        .help(BreakSnoozeText.left(context.snoozesLeft))
                        if let shortcut = BreakAccessibility.snoozeShortcutLabel {
                            Text(shortcut)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .opacity(isHighContrast ? 1 : 0.65)
                                .accessibilityHidden(true)
                        }
                    }
                }
                if context.canSkipNow {
                    VStack(spacing: 3) {
                        Button {
                            context.requestSkip()
                        } label: {
                            Text(context.isPreview ? LocalizedStringKey("Chiudi") : LocalizedStringKey("Salta"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(skipBackground)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(context.isPreview ? LocalizedStringKey("Chiudi l'anteprima") : LocalizedStringKey("Salta la pausa"))
                        .accessibilityHint(skipHint)
                        .help(skipHint)
                        if let shortcut = BreakAccessibility.skipShortcutLabel {
                            // Overlays never take the keyboard focus: the global shortcut is the keyboard path.
                            Text(shortcut)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .opacity(isHighContrast ? 1 : 0.65)
                                .accessibilityHidden(true)
                        }
                    }
                } else if context.skipUnlockDate == nil {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .opacity(isHighContrast ? 1 : 0.6)
                        .help("Modalità severa: la pausa non si salta")
                        .accessibilityLabel("Modalità severa: la pausa non si salta")
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
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
