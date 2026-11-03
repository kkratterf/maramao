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
    /// The status line on top of the menu ("Al lavoro · 18:32"), while the menu is open.
    private weak var statusLine: NSMenuItem?
    private var isMenuOpen = false
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
        // While the menu is open: the status line ticks, and the controls follow the timer.
        engine.$remaining
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshStatusLine() }
            }
            .store(in: &cancellables)
        engine.$phase.map { _ in () }
            .merge(with: engine.$isPaused.map { _ in () }, engine.$isBreakSnoozed.map { _ in () })
            .sink { [weak self] _ in
                Task { @MainActor in self?.rebuildIfOpen() }
            }
            .store(in: &cancellables)
        TimerToast.shared.anchor = { [weak self] in self?.visibleButtonFrame() }
    }

    /// Opens the menu under the pointer: for when the menu bar item is hidden behind the
    /// notch or a full menu bar, and the user opens Maramao again from Finder or Spotlight.
    func popUpAtPointer() {
        menuNeedsUpdate(menu)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: - Label

    /// The cat is always there, followed by the countdown while the timer runs.
    private func render(_ content: MenuBarContent, snoozedUntil: Date?) {
        guard let button = statusItem.button else { return }
        button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        if let until = snoozedUntil {
            // "Disattiva per…": the cat sleeps until the resume time.
            button.image = MenuBarCat.image
            button.title = " 💤 \(AvailabilityText.clock(until))"
        } else if let ring = content.ring {
            button.image = MenuBarRingRenderer.image(for: ring)
            button.title = ""
        } else {
            button.image = content.showsCat ? MenuBarCat.image : nil
            let gap = content.showsCat && !content.text.isEmpty ? " " : ""
            button.title = gap + content.text
        }
        button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading
    }

    /// Warns, once, when macOS hides the cat because the menu bar is full (behind the notch).
    /// Called a moment after launch, once the menu bar has laid out its items.
    func warnIfHidden() {
        guard statusItem.button != nil, visibleButtonFrame() == nil else { return }
        TimerToast.shared.showHiddenItemWarning()
    }

    /// The cat's frame on screen, or nil when it is hidden behind the notch or a full menu bar.
    private func visibleButtonFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window,
              window.occlusionState.contains(.visible) else { return nil }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        // A hidden item can keep a window that sits off every screen.
        guard NSScreen.screens.contains(where: { $0.frame.intersects(frame) }) else { return nil }
        return frame
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = makeItems()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        TimerToast.shared.close()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func rebuildIfOpen() {
        guard isMenuOpen else { return }
        menu.items = makeItems()
    }

    private func refreshStatusLine() {
        guard isMenuOpen, let statusLine else { return }
        let title = currentStatus().title
        if statusLine.title != title { statusLine.title = title }
    }

    /// Sections, each between separators: the timer, the modes, trying a mode, the rhythm,
    /// switching Maramao off for a while, updates, quit.
    private func makeItems() -> [NSMenuItem] {
        var items = timerItems()
        items.append(.separator())
        items.append(contentsOf: modeItems())
        items.append(.separator())
        items.append(tryModeItem())
        items.append(.separator())
        items.append(rhythmItem())
        if let snooze = snoozeItem() {
            items.append(.separator())
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

    private func currentStatus() -> TimerStatus {
        TimerStatus(
            phase: engine.phase,
            isPaused: engine.isPaused,
            remaining: engine.remaining,
            isBreakSnoozed: engine.isBreakSnoozed,
            offUntil: engine.phase == .idle && availability.isSnoozed ? availability.untilText() : nil
        )
    }

    /// Like the Timer in the Clock app: a line that says what is going on, then the controls,
    /// each with its symbol. The main one (start, pause, resume) carries ⇧⌘M. "Pausa" is
    /// kept for cat breaks only, so pausing the timer reads "Sospendi".
    private func timerItems() -> [NSMenuItem] {
        let status = currentStatus()
        let line = NSMenuItem(title: status.title, action: nil, keyEquivalent: "")
        line.isEnabled = false
        statusLine = line
        var items = [line]

        switch status {
        case .ready:
            items.append(startPauseItem(String(localized: "Avvia timer"), symbol: "play.fill") { [weak self] in
                self?.engine.startWork()
            })
        case .off:
            items.append(startPauseItem(String(localized: "Riattiva e avvia"), symbol: "play.fill") { [weak self] in
                self?.availability.endSnooze()
                self?.engine.startWork()
            })
        case .working:
            items.append(startPauseItem(String(localized: "Sospendi timer"), symbol: "pause.fill") { [weak self] in
                self?.engine.togglePause()
            })
        case .paused:
            items.append(startPauseItem(String(localized: "Riprendi timer"), symbol: "play.fill") { [weak self] in
                self?.engine.togglePause()
            })
        case .onBreak:
            let skip = item(String(localized: "Salta la pausa gatto"), symbol: "forward.end.fill") { [weak self] in
                self?.engine.skip()
            }
            skip.isEnabled = engine.canSkipBreak
            items.append(skip)
        case .breakSnoozed:
            items.append(item(String(localized: "Fai la pausa gatto adesso"), symbol: "pawprint.fill") { [weak self] in
                self?.engine.takeBreakNow()
            })
        }

        if status.canStop {
            let stop = item(String(localized: "Interrompi timer"), symbol: "stop.fill") { [weak self] in
                self?.engine.reset()
            }
            stop.toolTip = String(localized: "Ferma il timer e torna all'inizio")
            items.append(stop)
            items.append(item(String(localized: "Fai la pausa gatto adesso"), symbol: "pawprint.fill") { [weak self] in
                self?.engine.takeBreakNow()
            })
        }
        return items
    }

    /// "Modalità": pick how the cats stop you.
    private func modeItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = [Self.header(String(localized: "Modalità"))]
        for mode in BreakModeID.allCases {
            let entry = item(mode.title) { [weak self] in self?.settings.breakMode = mode }
            entry.state = settings.breakMode == mode ? .on : .off
            entry.toolTip = mode.subtitle
            entry.indentationLevel = Self.headerIndent
            items.append(entry)
        }
        return items
    }

    /// "Prova la modalità": a 30-second fake break with the picked mode, apart from the
    /// modes because it does something instead of choosing something.
    private func tryModeItem() -> NSMenuItem {
        let tryIt = item(String(localized: "Prova la modalità")) { [weak self] in
            guard let self else { return }
            self.engine.preview(self.settings.breakMode, seconds: 30)
        }
        tryIt.isEnabled = !engine.phase.isBreak && engine.activeBreakMode == nil
        tryIt.toolTip = String(localized: "Una pausa finta di 30 secondi")
        return tryIt
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

    /// "Disattiva per ▸ 30 minuti, 1 ora, …": switches Maramao off for a while.
    private func snoozeItem() -> NSMenuItem? {
        guard !engine.phase.isBreak, !availability.isSnoozed else { return nil }
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for option in SnoozeOption.allCases {
            submenu.addItem(item(option.title) { [weak self] in self?.engine.snooze(option) })
        }
        let parent = NSMenuItem(title: String(localized: "Disattiva per"), action: nil, keyEquivalent: "")
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
    private func startPauseItem(_ title: String, symbol: String, action: @escaping () -> Void) -> NSMenuItem {
        let entry = item(title, symbol: symbol, action: action)
        let shortcuts = GlobalShortcuts.shared
        if shortcuts.isEnabled(.startPause), !shortcuts.failed.contains(.startPause) {
            let combo = GlobalShortcut.startPause.combo
            entry.keyEquivalent = combo.keyEquivalent
            entry.keyEquivalentModifierMask = combo.modifierFlags
        }
        return entry
    }

    private func item(_ title: String, key: String = "", symbol: String? = nil, action: @escaping () -> Void) -> NSMenuItem {
        let entry = ClosureMenuItem(title: title, keyEquivalent: key, action: action)
        if let symbol {
            entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
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
