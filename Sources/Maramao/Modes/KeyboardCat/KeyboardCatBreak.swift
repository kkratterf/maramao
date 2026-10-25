import AppKit
import SwiftUI

/// "Il gatto sulla tastiera": a big drawn Mac keyboard fills the screen and a cat is fast asleep
/// on it. Maramao takes the keyboard focus for the break, so every key you press lands here:
/// the key lights up, the cat "types" nonsense into the text field above, twitches its tail and,
/// after a few presses, lets you know it is sleeping there.
///
/// Escape is swallowed. Maramao's own Cmd-Q, Cmd-H and Cmd-W (which would quit, hide or close
/// the break) are intercepted with a line from the cat; every other shortcut goes on as usual.
/// When the break ends, the app that was active before gets the focus back.
/// Uses only a local event monitor: no Accessibility permission needed.
@MainActor
final class KeyboardCatBreak: BreakMode {
    private var windows: [OverlayWindow] = []
    private var model: KeyboardCatModel?
    private var monitor: Any?
    private var tickTimer: Timer?
    private var previousApp: NSRunningApplication?

    private var hasBegun = false
    private var hasEnded = false
    private var finished = false

    private var pressCount = 0
    private var phrase: [Character] = []
    private var phraseIndex = 0
    private var lastPhrase = -1
    private var sleepyIndex = 0
    private var pressedUntil: [Int: Date] = [:]
    private var catUntil: [Int: Date] = [:]
    private var bubbleUntil = Date.distantPast
    private var bubbleShownAt = Date.distantPast

    /// The cat mumbles something every this many key presses.
    private let pressesPerLine = 6

    func begin(context: BreakContext) {
        guard !hasBegun, !hasEnded else { return }
        hasBegun = true

        let palettes: [CatPalette] = [.orange, .gray, .black, .cream]
        let model = KeyboardCatModel(palette: palettes.randomElement() ?? .orange)
        self.model = model

        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            previousApp = front
        }

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let mainScreen = NSScreen.main ?? screens[0]
        let fadeIn = min(0.6, context.duration / 40)
        var keyWindow: OverlayWindow?
        for screen in screens {
            let window = OverlayWindow(screen: screen)
            let isMain = screen == mainScreen
            window.allowsKey = isMain
            window.host(KeyboardCatScene(model: model, context: context, isMain: isMain))
            window.alphaValue = 0
            window.show()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = fadeIn
                window.animator().alphaValue = 1
            }
            if isMain { keyWindow = window }
            windows.append(window)
        }

        installMonitor()

        // Take the keyboard: keystrokes now come to us instead of the app the user was in.
        NSApp.activate(ignoringOtherApps: true)
        keyWindow?.makeKeyAndOrderFront(nil)

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            let owner = self
            Task { @MainActor in owner?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        removeMonitorAndTimer()
        // Give the keyboard back right away; the cat takes a moment to stretch.
        restorePreviousApp()

        guard let model, !windows.isEmpty else {
            finish()
            return
        }
        model.pressedKeys = []
        model.catKeys = []
        model.bubble = String(localized: "Ok, ora puoi lavorare.")
        model.hudMessage = String(localized: "Il gatto si alza. Pausa finita.")
        model.setPhase(.stretching)

        // A stretch, then fade out. Everything is closed within ~2 s.
        // The task captures self strongly to stay alive after the coordinator lets go.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let closing = self.windows
            self.windows = []
            for window in closing {
                window.fadeOutAndClose(duration: 0.5)
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
            self.finish()
        }
    }

    // MARK: - Lifecycle

    private func finish() {
        guard !finished else { return }
        finished = true
        removeMonitorAndTimer()
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = []
        model = nil
    }

    private func removeMonitorAndTimer() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func restorePreviousApp() {
        guard let app = previousApp else { return }
        previousApp = nil
        // Only if the user did not switch app on their own in the meantime.
        if NSApp.isActive && !app.isTerminated {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    // MARK: - Keyboard

    private func installMonitor() {
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let owner = self
            let action = keyboardCatAction(for: event)
            let code = event.keyCode
            switch action {
            case .press:
                Task { @MainActor in owner?.keyPressed(code) }
                return nil
            case .escape:
                Task { @MainActor in owner?.escapePressed() }
                return nil
            case .quit:
                Task { @MainActor in owner?.quitAttempted() }
                return nil
            case .modifier:
                Task { @MainActor in owner?.modifierChanged(code) }
                return event
            case .passThrough:
                return event
            }
        })
    }

    private func keyPressed(_ code: UInt16) {
        guard !hasEnded, let model else { return }
        let now = Date()
        pressCount += 1
        Self.light(KeyboardCatLayout.keys(forKeyCode: code), in: &pressedUntil, until: now.addingTimeInterval(0.22))

        // The cat types a few characters of its current nonsense with the keys it lies on.
        if phraseIndex >= phrase.count {
            nextPhrase()
        }
        let count = Int.random(in: 2...5)
        var chunk = ""
        var catLit: [Int] = []
        for _ in 0..<count where phraseIndex < phrase.count {
            let character = phrase[phraseIndex]
            phraseIndex += 1
            chunk.append(character)
            if let key = KeyboardCatLayout.key(for: character) {
                catLit.append(key)
            }
        }
        if catLit.isEmpty, let random = KeyboardCatLayout.keysUnderCat.randomElement() {
            catLit.append(random)
        }
        Self.light(catLit, in: &catUntil, until: now.addingTimeInterval(0.35))

        var typed = model.typed + chunk
        if typed.count > 400 {
            typed = String(typed.suffix(300))
        }
        model.typed = typed
        model.twitchDate = now

        if pressCount % pressesPerLine == 0 && now.timeIntervalSince(bubbleShownAt) > 1.5 {
            let lines = KeyboardCatLines.sleepy
            say(lines[sleepyIndex % lines.count], duration: 2.6)
            sleepyIndex += 1
        }
        syncSets(now: now)
    }

    private func escapePressed() {
        guard !hasEnded, let model else { return }
        let now = Date()
        Self.light(KeyboardCatLayout.keys(forKeyCode: 53), in: &pressedUntil, until: now.addingTimeInterval(0.3))
        model.twitchDate = now
        if now.timeIntervalSince(bubbleShownAt) > 1.2 {
            say(KeyboardCatLines.escape.randomElement() ?? "Mrrr.", duration: 2.2)
        }
        syncSets(now: now)
    }

    private func quitAttempted() {
        guard !hasEnded, let model else { return }
        let now = Date()
        Self.light(KeyboardCatLayout.keys(forKeyCode: 55) + KeyboardCatLayout.keys(forKeyCode: 54), in: &pressedUntil, until: now.addingTimeInterval(0.4))
        model.twitchDate = now
        say(KeyboardCatLines.quit, duration: 2.8)
        syncSets(now: now)
    }

    private func modifierChanged(_ code: UInt16) {
        guard !hasEnded else { return }
        let now = Date()
        Self.light(KeyboardCatLayout.keys(forKeyCode: code), in: &pressedUntil, until: now.addingTimeInterval(0.25))
        syncSets(now: now)
    }

    private func nextPhrase() {
        let phrases = KeyboardCatLines.typing
        var index = Int.random(in: 0..<phrases.count)
        if index == lastPhrase {
            index = (index + 1) % phrases.count
        }
        lastPhrase = index
        phrase = Array(phrases[index])
        phraseIndex = 0
    }

    private static func light(_ keys: [Int], in table: inout [Int: Date], until date: Date) {
        for key in keys {
            table[key] = date
        }
    }

    private func say(_ text: String, duration: TimeInterval) {
        guard let model else { return }
        let now = Date()
        model.bubble = text
        bubbleShownAt = now
        bubbleUntil = now.addingTimeInterval(duration)
    }

    // MARK: - Clock

    private func tick() {
        guard !hasEnded, let model else { return }
        let now = Date()
        syncSets(now: now)
        if model.bubble != nil && now >= bubbleUntil {
            model.bubble = nil
        }
    }

    /// Drops expired lights and publishes the lit sets only when they change.
    private func syncSets(now: Date) {
        guard let model else { return }
        pressedUntil = pressedUntil.filter { $0.value > now }
        catUntil = catUntil.filter { $0.value > now }
        let pressed = Set(pressedUntil.keys)
        let cat = Set(catUntil.keys)
        if model.pressedKeys != pressed { model.pressedKeys = pressed }
        if model.catKeys != cat { model.catKeys = cat }
    }
}

/// What to do with a key event. Decided synchronously, outside the main actor.
private enum KeyboardCatAction {
    /// A normal key: the cat types, the event is swallowed (no beep, nothing reaches the app).
    case press
    case escape
    /// Maramao's own Cmd-Q / Cmd-H / Cmd-W: swallowed, the cat refuses.
    case quit
    case modifier
    /// Other shortcuts: handled normally by the app.
    case passThrough
}

private func keyboardCatAction(for event: NSEvent) -> KeyboardCatAction {
    switch event.type {
    case .flagsChanged:
        return .modifier
    case .keyDown:
        if event.keyCode == 53 {
            return .escape
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            let key = (event.charactersIgnoringModifiers ?? "").lowercased()
            let others = flags.subtracting([.command, .capsLock, .numericPad, .function])
            if others.isEmpty && (key == "q" || key == "h" || key == "w") {
                return .quit
            }
            return .passThrough
        }
        return .press
    default:
        return .passThrough
    }
}
