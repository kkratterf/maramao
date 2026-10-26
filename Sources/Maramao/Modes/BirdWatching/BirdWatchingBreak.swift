import AppKit
import SwiftUI

/// "Il gatto alla finestra": every screen becomes a window onto a garden, birds hop on a
/// branch and the cat watches them, chattering now and then. The HUD and the caption invite
/// the user to look far away, which makes this the eye-rest companion of the 20-20-20 rule.
///
/// Nothing here needs a permission: no input monitors, no window list, no screen capture.
/// One timer per break rotates the caption and the chatter; everything that moves is drawn
/// from the timeline's own date inside the canvases, at most 15 fps.
@MainActor
final class BirdWatchingBreak: BreakMode {
    private var windows: [OverlayWindow] = []
    private var model: BirdWatchingModel?
    private var timer: Timer?

    private var hasBegun = false
    private var hasEnded = false

    private var nextCaptionDate = Date.distantFuture
    private var nextChatterDate = Date.distantFuture
    private var chatterUntil = Date.distantPast

    /// Seconds a caption stays before the next one.
    private let captionInterval: TimeInterval = 13
    /// Seconds between two chatters, and how long one lasts.
    private let chatterInterval: TimeInterval = 19
    private let chatterDuration: TimeInterval = 1.8

    func begin(context: BreakContext) {
        guard !hasBegun, !hasEnded else { return }
        hasBegun = true

        let model = BirdWatchingModel(
            palette: CatPalette.random(),
            caption: BirdWatchingLines.nextCaption(avoiding: "")
        )
        self.model = model

        let now = Date()
        nextCaptionDate = now.addingTimeInterval(captionInterval)
        nextChatterDate = now.addingTimeInterval(6)

        let screens = BreakScreens.current()
        let mainScreen = BreakScreens.primary(in: screens)
        windows = screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.host(BirdWatchingScene(model: model, context: context, isMain: screen == mainScreen))
            window.alphaValue = 0
            window.show()
            // The window opens like a curtain being drawn: a slow fade, never a flash.
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = min(1.0, context.duration / 20)
                window.animator().alphaValue = 1
            }
            return window
        }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            let owner = self
            Task { @MainActor in owner?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        timer?.invalidate()
        timer = nil

        let closing = windows
        windows = []
        model?.isChattering = false
        // Everything is gone within ~0.8 s, well inside the 3 s the contract allows.
        for window in closing {
            window.fadeOutAndClose(duration: 0.6)
        }
        model = nil
    }

    private func tick() {
        guard !hasEnded, let model else { return }
        let now = Date()

        if now >= nextCaptionDate {
            model.caption = BirdWatchingLines.nextCaption(avoiding: model.caption)
            nextCaptionDate = now.addingTimeInterval(captionInterval)
        }

        if model.isChattering, now >= chatterUntil {
            model.isChattering = false
        } else if !model.isChattering, now >= nextChatterDate {
            model.isChattering = true
            chatterUntil = now.addingTimeInterval(chatterDuration)
            nextChatterDate = now.addingTimeInterval(chatterInterval)
            CatSounds.shared.chirp()
        }
    }
}
