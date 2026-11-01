import AppKit
import Combine

/// Shared, observable state of the sleepy cat. The break mode drives it, the scene draws it.
@MainActor
final class SleepyCatModel: ObservableObject {
    enum Phase: Equatable {
        /// The sleeping cat. The only phase that counts as rest.
        case asleep
        /// Someone touched the mouse or the keyboard: an angry cat glares at them.
        case awake
    }

    @Published private(set) var phase: Phase = .asleep
    /// The angry cat on screen while awake. A different photo every time it wakes up.
    @Published private(set) var angryPhoto: NSImage?
    /// The sleeping cat, one per break.
    let sleepingPhoto: NSImage?

    init(sleepingPhoto: NSImage?) {
        self.sleepingPhoto = sleepingPhoto
    }

    func wake(with photo: NSImage?) {
        angryPhoto = photo
        phase = .awake
    }

    func fallAsleep() {
        phase = .asleep
    }
}
