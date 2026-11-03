import AppKit
import Combine

/// Shared, observable state of the sleepy cat. The break mode drives it, the scene draws it.
@MainActor
final class SleepyCatModel: ObservableObject {
    enum Phase: Equatable {
        /// The sleeping cat. The only phase that counts as rest.
        case asleep
        /// Someone touched the mouse or the keyboard: the same cat, now angry, glares at them.
        case awake
    }

    @Published private(set) var phase: Phase = .asleep
    /// What the cat says under its photo. Changes every time it is woken up.
    @Published private(set) var line: String
    /// Bumped with every new line, so the caption animates even when a line comes back.
    @Published private(set) var lineID = 0

    /// One pair per break: this cat sleeps and this cat gets angry, for the whole break.
    let sleepingPhoto: NSImage?
    let angryPhoto: NSImage?

    init(sleepingPhoto: NSImage?, angryPhoto: NSImage?, line: String) {
        self.sleepingPhoto = sleepingPhoto
        self.angryPhoto = angryPhoto
        self.line = line
    }

    func wake(saying line: String) {
        self.line = line
        lineID += 1
        phase = .awake
    }

    func fallAsleep(saying line: String) {
        self.line = line
        lineID += 1
        phase = .asleep
    }
}
