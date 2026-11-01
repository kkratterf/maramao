import AppKit
import Combine
import MaramaoCore

/// The menu bar item and its menu: a plain `NSMenu`, so it looks and behaves like every
/// other menu on the Mac.
///
/// The menu is rebuilt every time it opens, so it always matches the timer. The
/// start/pause key equivalent mirrors the global shortcut (`GlobalShortcut.startPause`).
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let model = MenuBarModel()
    private var cancellables: Set<AnyCancellable> = []

    private var engine: PomodoroEngine { .shared }
    private var settings: AppSettings { .shared }
    private var availability: AvailabilityStore { .shared }
    private var updater: AppUpdater { .shared }

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.toolTip = "Maramao"
        model.$content
            .combineLatest(availability.$snoozedUntil, engine.$phase)
            .sink { [weak self] content, snoozedUntil, phase in
                self?.render(content, snoozedUntil: phase == .idle ? snoozedUntil : nil)
            }
            .store(in: &cancellables)
    }

    /// Opens the menu under the pointer: for when the menu bar item is hidden behind the
    /// notch or a full menu bar, and the user opens Maramao again from Finder or Spotlight.
    func popUpAtPointer() {
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Label

    private func render(_ content: MenuBarContent, snoozedUntil: Date?) {
        guard let button = statusItem.button else { return }
        if let until = snoozedUntil {
            // "Pausa per…": a sleeping cat and the resume time.
            button.image = nil
            button.title = "😴 \(AvailabilityText.clock(until))"
        } else if let ring = content.ring {
            button.title = ""
            button.image = MenuBarRingRenderer.image(for: ring)
        } else {
            button.image = nil
            button.title = content.text
        }
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = makeItems()
    }

    private func makeItems() -> [NSMenuItem] {
        var items = timerItems()
        items.append(.separator())
        items.append(contentsOf: modeItems())
        items.append(rhythmItem())
        if let snooze = snoozeItem() {
            items.append(snooze)
        }
        items.append(.separator())
        if updater.isAvailable {
            items.append(updateItem())
            items.append(.separator())
        }
        items.append(item(String(localized: "Esci da Maramao"), key: "q") { NSApp.terminate(nil) })
        return items
    }

    /// The main action on top (start, pause or skip), with what else makes sense right now.
    private func timerItems() -> [NSMenuItem] {
        switch engine.phase {
        case .idle:
            if availability.isSnoozed {
                return [item(String(localized: "Riprendi ora")) { [weak self] in
                    self?.availability.endSnooze()
                    self?.engine.startWork()
                }]
            }
            return [startPauseItem(String(localized: "Inizia a lavorare")) { [weak self] in self?.engine.startWork() }]
        case .work:
            let title = engine.isPaused ? String(localized: "Riprendi") : String(localized: "Metti in pausa")
            return [
                startPauseItem(title) { [weak self] in self?.engine.togglePause() },
                item(String(localized: "Pausa gatto ora")) { [weak self] in self?.engine.takeBreakNow() },
                item(String(localized: "Ricomincia da capo")) { [weak self] in self?.engine.reset() },
            ]
        case .shortBreak, .longBreak:
            if engine.isBreakSnoozed {
                return [item(String(localized: "Pausa gatto ora")) { [weak self] in self?.engine.takeBreakNow() }]
            }
            let skip = item(String(localized: "Salta pausa")) { [weak self] in self?.engine.skip() }
            skip.isEnabled = engine.canSkipBreak
            return [skip]
        }
    }

    /// "Modalità": pick how the cats stop you, and try the picked one right away.
    private func modeItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = [Self.header(String(localized: "Modalità"))]
        for mode in BreakModeID.allCases {
            let entry = item(mode.title) { [weak self] in self?.settings.breakMode = mode }
            entry.state = settings.breakMode == mode ? .on : .off
            entry.toolTip = mode.subtitle
            entry.indentationLevel = Self.headerIndent
            items.append(entry)
        }
        let tryIt = item(String(localized: "Prova la modalità")) { [weak self] in
            guard let self else { return }
            self.engine.preview(self.settings.breakMode, seconds: 30)
        }
        tryIt.isEnabled = !engine.phase.isBreak && engine.activeBreakMode == nil
        tryIt.toolTip = String(localized: "Una pausa finta di 30 secondi")
        tryIt.indentationLevel = Self.headerIndent
        items.append(tryIt)
        return items
    }

    /// "Ritmo ▸ Classico 25/5, Lungo 50/10, Profondo 90/20".
    private func rhythmItem() -> NSMenuItem {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let custom = settings.customPomodoroConfig
        // "Personalizzato" (the default preset) is shown only to people who set their own
        // durations before: with the stock durations it is the same as Classico.
        let current = settings.timerPreset
        let customIsClassic = current == .custom && custom == TimerPreset.classic.config(custom: custom)
        let presets = TimerPreset.allCases.filter { $0 != .custom || (current == .custom && !customIsClassic) }
        for preset in presets {
            let entry = item(preset.menuTitle(custom: custom)) { [weak self] in self?.engine.setTimerPreset(preset) }
            let isOn = preset == current || (preset == .classic && customIsClassic)
            entry.state = isOn ? .on : .off
            submenu.addItem(entry)
        }
        let parent = NSMenuItem(title: String(localized: "Ritmo"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    /// "Pausa per ▸ 30 minuti, 1 ora, …": stops Maramao for a while.
    private func snoozeItem() -> NSMenuItem? {
        guard !engine.phase.isBreak, !availability.isSnoozed else { return nil }
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for option in SnoozeOption.allCases {
            submenu.addItem(item(option.title) { [weak self] in self?.engine.snooze(option) })
        }
        let parent = NSMenuItem(title: String(localized: "Pausa per"), action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    private func updateItem() -> NSMenuItem {
        let title: String
        if let version = updater.pendingUpdateVersion {
            title = String(localized: "Aggiorna alla versione \(version)…")
        } else {
            title = String(localized: "Controlla aggiornamenti…")
        }
        let entry = item(title) { [weak self] in self?.updater.checkForUpdates() }
        entry.isEnabled = updater.pendingUpdateVersion != nil || updater.canCheckForUpdates
        return entry
    }

    // MARK: - Building blocks

    /// Items under a header are indented on macOS 13, which has no real section headers.
    private static var headerIndent: Int {
        if #available(macOS 14, *) { return 0 }
        return 1
    }

    private static func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14, *) {
            return NSMenuItem.sectionHeader(title: title)
        }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// The start/pause item shows the global shortcut as its key equivalent.
    private func startPauseItem(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let entry = item(title, action: action)
        let shortcuts = GlobalShortcuts.shared
        if shortcuts.isEnabled(.startPause), !shortcuts.failed.contains(.startPause) {
            let combo = GlobalShortcut.startPause.combo
            entry.keyEquivalent = combo.keyEquivalent
            entry.keyEquivalentModifierMask = combo.modifierFlags
        }
        return entry
    }

    private func item(_ title: String, key: String = "", action: @escaping () -> Void) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title, keyEquivalent: key, action: action)
        return entry
    }
}

/// A menu item that runs a closure, so the menu needs no selector per command.
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run(_:)), keyEquivalent: keyEquivalent)
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run(_ sender: Any?) {
        handler()
    }
}
