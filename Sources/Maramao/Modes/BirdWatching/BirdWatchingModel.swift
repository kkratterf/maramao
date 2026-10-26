import SwiftUI

/// Shared, observable state of the birdwatching break. The break mode drives it, the scene draws it.
///
/// Everything that moves (birds, leaves, clouds) is computed from the timeline's date inside the
/// canvas, so this model only changes a few times per break: once per caption and once per chatter.
@MainActor
final class BirdWatchingModel: ObservableObject {
    /// The invitation shown under the HUD, rotated every few seconds.
    @Published var caption: String
    /// True while the cat chatters at the birds ("ek ek ek").
    @Published var isChattering = false

    let palette: CatPalette

    init(palette: CatPalette, caption: String) {
        self.palette = palette
        self.caption = caption
    }

    var hudMessage: String {
        String(localized: "Guarda fuori, lontano dallo schermo.")
    }
}

/// What the cat at the window suggests: every line is about looking far away.
enum BirdWatchingLines {
    static let captions: [String] = [
        String(localized: "Metti a fuoco qualcosa a sei metri da te."),
        String(localized: "Venti secondi di sguardo lontano: è la regola 20-20-20."),
        String(localized: "Se hai una finestra vera, è il momento di aprirla."),
        String(localized: "Sbatti le palpebre, piano. Ancora una volta."),
        String(localized: "Gli uccellini li guarda il gatto. Tu guarda l'orizzonte."),
        String(localized: "Cerca il punto più lontano della stanza e restaci."),
        String(localized: "Spalle giù, occhi lontani. Il resto può aspettare."),
    ]

    /// A caption different from the previous one.
    static func nextCaption(avoiding previous: String) -> String {
        let candidates = captions.filter { $0 != previous }
        return candidates.randomElement() ?? captions.first ?? ""
    }
}
