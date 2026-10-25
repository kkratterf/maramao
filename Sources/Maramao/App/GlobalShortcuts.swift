import SwiftUI
import Carbon.HIToolbox

/// The fixed set of system-wide shortcuts Maramao offers.
enum GlobalShortcut: String, CaseIterable, Identifiable {
    case startPause
    case takeBreak
    case skip
    case snooze

    var id: String { rawValue }

    /// Id used with `HotKeyCenter`, namespaced so other features can register their own.
    var hotKeyID: String { "shortcut.\(rawValue)" }

    var combo: HotKeyCombo {
        switch self {
        case .startPause: return HotKeyCombo(keyCode: kVK_ANSI_P, modifiers: HotKeyCombo.controlOptionCommand)
        case .takeBreak: return HotKeyCombo(keyCode: kVK_ANSI_B, modifiers: HotKeyCombo.controlOptionCommand)
        case .skip: return HotKeyCombo(keyCode: kVK_ANSI_S, modifiers: HotKeyCombo.controlOptionCommand)
        case .snooze: return HotKeyCombo(keyCode: kVK_ANSI_R, modifiers: HotKeyCombo.controlOptionCommand)
        }
    }

    var title: String {
        switch self {
        case .startPause: return String(localized: "Inizia / metti in pausa")
        case .takeBreak: return String(localized: "Pausa gatto ora")
        case .skip: return String(localized: "Salta (quando si può)")
        case .snooze: return String(localized: "Rimanda la pausa (quando si può)")
        }
    }

    fileprivate var defaultsKey: String { "shortcutEnabled.\(rawValue)" }
}

/// Owns the on/off state of each global shortcut and keeps `HotKeyCenter`
/// in sync with it. Shortcuts are on by default.
@MainActor
final class GlobalShortcuts: ObservableObject {
    static let shared = GlobalShortcuts()

    /// Shortcuts the user turned on.
    @Published private(set) var enabled: Set<GlobalShortcut> = []
    /// Shortcuts macOS refused, usually because another app owns the combination.
    @Published private(set) var failed: Set<GlobalShortcut> = []

    private let defaults: UserDefaults
    private var isActive = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var initial: Set<GlobalShortcut> = []
        for shortcut in GlobalShortcut.allCases {
            defaults.register(defaults: [shortcut.defaultsKey: true])
            if defaults.bool(forKey: shortcut.defaultsKey) { initial.insert(shortcut) }
        }
        enabled = initial
    }

    /// Registers every enabled shortcut. Call once at launch.
    func activate() {
        isActive = true
        for shortcut in GlobalShortcut.allCases {
            apply(shortcut)
        }
    }

    func isEnabled(_ shortcut: GlobalShortcut) -> Bool {
        enabled.contains(shortcut)
    }

    func setEnabled(_ shortcut: GlobalShortcut, _ isOn: Bool) {
        if isOn { enabled.insert(shortcut) } else { enabled.remove(shortcut) }
        defaults.set(isOn, forKey: shortcut.defaultsKey)
        apply(shortcut)
    }

    func binding(_ shortcut: GlobalShortcut) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.isEnabled(shortcut) },
            set: { self.setEnabled(shortcut, $0) }
        )
    }

    /// " (⌃⌥⌘P)" when the shortcut is active, for button tooltips; empty otherwise.
    func hint(_ shortcut: GlobalShortcut) -> String {
        guard isEnabled(shortcut), !failed.contains(shortcut) else { return "" }
        return " (\(shortcut.combo.displayString))"
    }

    private func apply(_ shortcut: GlobalShortcut) {
        guard isActive else { return }
        let center = HotKeyCenter.shared
        guard isEnabled(shortcut) else {
            center.unregister(id: shortcut.hotKeyID)
            failed.remove(shortcut)
            return
        }
        let ok = center.register(id: shortcut.hotKeyID, combo: shortcut.combo) {
            Task { @MainActor in GlobalShortcuts.perform(shortcut) }
        }
        if ok { failed.remove(shortcut) } else { failed.insert(shortcut) }
    }

    private static func perform(_ shortcut: GlobalShortcut) {
        let engine = PomodoroEngine.shared
        switch shortcut {
        case .startPause:
            switch engine.phase {
            case .idle: engine.startWork()
            case .work: engine.togglePause()
            case .shortBreak, .longBreak: break // Breaks cannot be paused.
            }
        case .takeBreak:
            guard !engine.phase.isBreak || engine.isBreakSnoozed else { return }
            engine.takeBreakNow()
        case .skip:
            // `skip()` itself refuses to end a break before it may be skipped.
            engine.skip()
        case .snooze:
            // `snoozeBreak()` itself checks the daily limit and the offer window.
            engine.snoozeBreak()
        }
    }
}

/// Settings section "Scorciatoie": the fixed shortcuts with an on/off toggle each.
struct ShortcutsSettingsSection: View {
    @ObservedObject private var shortcuts = GlobalShortcuts.shared

    var body: some View {
        Section("Scorciatoie") {
            ForEach(GlobalShortcut.allCases) { shortcut in
                Toggle(isOn: shortcuts.binding(shortcut)) {
                    HStack {
                        Text(shortcut.title)
                        Spacer()
                        Text(shortcut.combo.displayString)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                if shortcuts.failed.contains(shortcut) {
                    Text("Combinazione già usata da un'altra app.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Text("Funzionano da qualsiasi app, senza permessi speciali.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
