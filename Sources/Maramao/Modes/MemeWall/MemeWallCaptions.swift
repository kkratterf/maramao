import Foundation

/// A top/bottom caption pair for a meme card. User-facing, so Italian.
struct MemeWallCaption {
    enum Kind {
        /// Just a joke.
        case joke
        /// Nudges a healthy break action (water, stretching, looking away).
        case tip
    }

    let top: String
    let bottom: String
    var kind: Kind = .joke

    static let all: [MemeWallCaption] = jokes + tips

    static let jokes: [MemeWallCaption] = [
        MemeWallCaption(top: String(localized: "QUANDO DICI 'ANCORA UN'EMAIL'"), bottom: String(localized: "E IL GATTO DICE NO")),
        MemeWallCaption(top: String(localized: "PAUSA?"), bottom: String(localized: "PAUSA.")),
        MemeWallCaption(top: String(localized: "HO CHIUSO IL TUO LAPTOP"), bottom: String(localized: "CON IL SEDERE")),
        MemeWallCaption(top: String(localized: "IL TUO POMODORO È SCADUTO"), bottom: String(localized: "ORA SI FANNO LE FUSA")),
        MemeWallCaption(top: String(localized: "TU: 'SONO PRODUTTIVO'"), bottom: String(localized: "IO: DORMO 16 ORE AL GIORNO")),
        MemeWallCaption(top: String(localized: "LA RIUNIONE POTEVA ESSERE UN'EMAIL"), bottom: String(localized: "L'EMAIL POTEVA ESSERE UN PISOLINO")),
        MemeWallCaption(top: String(localized: "CTRL+S"), bottom: String(localized: "CTRL+SONNELLINO")),
        MemeWallCaption(top: String(localized: "HAI SCRITTO 'ASDFGHJKL'?"), bottom: String(localized: "NO, SONO PASSATO IO")),
        MemeWallCaption(top: String(localized: "IL CODICE COMPILA?"), bottom: String(localized: "NON MI INTERESSA. CROCCHETTE.")),
        MemeWallCaption(top: String(localized: "25 MINUTI DI LAVORO"), bottom: String(localized: "5 MINUTI DI ME. NON TRATTABILE.")),
        MemeWallCaption(top: String(localized: "LA SCRIVANIA È MIA"), bottom: String(localized: "IL TUO MOUSE È UN GIOCATTOLO")),
        MemeWallCaption(top: String(localized: "DEADLINE?"), bottom: String(localized: "MAI SENTITA")),
        MemeWallCaption(top: String(localized: "STAVI LAVORANDO?"), bottom: String(localized: "CHE PECCATO")),
        MemeWallCaption(top: String(localized: "IL BUG NON SPARISCE"), bottom: String(localized: "IO SÌ. SOTTO IL LETTO.")),
        MemeWallCaption(top: String(localized: "SEI IN CALL?"), bottom: String(localized: "PERFETTO, ARRIVO IN CAMERA")),
        MemeWallCaption(top: String(localized: "TU GUARDI LO SCHERMO"), bottom: String(localized: "IO GUARDO TE. E GIUDICO.")),
        MemeWallCaption(top: String(localized: "HAI 47 TAB APERTE"), bottom: String(localized: "IO ZERO. E STO BENISSIMO.")),
        MemeWallCaption(top: String(localized: "OGNI POMODORO"), bottom: String(localized: "MERITA UN GRATTINO")),
        MemeWallCaption(top: String(localized: "NON È PIGRIZIA"), bottom: String(localized: "È RISPARMIO ENERGETICO")),
        MemeWallCaption(top: String(localized: "LA TASTIERA È CALDA"), bottom: String(localized: "QUINDI È UN LETTO")),
        MemeWallCaption(top: String(localized: "MULTITASKING:"), bottom: String(localized: "DORMIRE E GIUDICARTI INSIEME")),
        MemeWallCaption(top: String(localized: "'FINISCO SOLO QUESTA COSA'"), bottom: String(localized: "SONO 3 POMODORI CHE LO DICI")),
        MemeWallCaption(top: String(localized: "HO MESSO LA ZAMPA SU INVIO"), bottom: String(localized: "SPERO NON FOSSE IMPORTANTE")),
        MemeWallCaption(top: String(localized: "IL TUO CAPO TI CERCA"), bottom: String(localized: "IL TUO GATTO TI HA TROVATO")),
        MemeWallCaption(top: String(localized: "NIENTE NOTIFICHE"), bottom: String(localized: "SOLO MIAGOLII")),
        MemeWallCaption(top: String(localized: "MODALITÀ FOCUS"), bottom: String(localized: "SULLA CIOTOLA VUOTA")),
        MemeWallCaption(top: String(localized: "PRIMA LA PAUSA"), bottom: String(localized: "POI LA PAUSA")),
        MemeWallCaption(top: String(localized: "PRODUTTIVITÀ: \(0)%"), bottom: String(localized: "MORBIDEZZA: \(100)%")),
        MemeWallCaption(top: String(localized: "IL FILE ERA SALVATO?"), bottom: String(localized: "ORMAI È TARDI")),
        MemeWallCaption(top: String(localized: "HO LETTO IL TUO CODICE"), bottom: String(localized: "MI SERVE UN PISOLINO")),
        MemeWallCaption(top: String(localized: "SEI STANCO?"), bottom: String(localized: "ANCH'IO. E NON HO FATTO NIENTE.")),
        MemeWallCaption(top: String(localized: "UNA SCATOLA DI CARTONE"), bottom: String(localized: "MEGLIO DI QUALSIASI UFFICIO")),
        MemeWallCaption(top: String(localized: "LA SEDIA ERA TUA"), bottom: String(localized: "ERA.")),
        MemeWallCaption(top: String(localized: "IL TIMER SUONA"), bottom: String(localized: "IO MIAGOLO PIÙ FORTE")),
        MemeWallCaption(top: String(localized: "BACKUP FATTO?"), bottom: String(localized: "IO HO FATTO LE FUSA")),
        MemeWallCaption(top: String(localized: "UN ALTRO CAFFÈ?"), bottom: String(localized: "UN ALTRO PISOLINO.")),
        MemeWallCaption(top: String(localized: "QUANDO IL TIMER FA DRIN"), bottom: String(localized: "E TU FAI FINTA DI NIENTE")),
        MemeWallCaption(top: String(localized: "LAVORI DA CASA?"), bottom: String(localized: "NO. LAVORI A CASA MIA.")),
        MemeWallCaption(top: String(localized: "'DOMANI LO FINISCO'"), bottom: String(localized: "MOTTO UFFICIALE DEI GATTI")),
        MemeWallCaption(top: String(localized: "TO-DO LIST: 1. DORMIRE"), bottom: String(localized: "2. DORMIRE DI NUOVO")),
        MemeWallCaption(top: String(localized: "L'ALGORITMO È SEMPLICE"), bottom: String(localized: "SE C'È SOLE, CI DORMO")),
        MemeWallCaption(top: String(localized: "STANDUP MEETING?"), bottom: String(localized: "IO SONO SDRAIATO, GRAZIE")),
        MemeWallCaption(top: String(localized: "GIT COMMIT"), bottom: String(localized: "ALLA SIESTA")),
        MemeWallCaption(top: String(localized: "VAI IN PAUSA"), bottom: String(localized: "O LA TAZZA CADE DAL TAVOLO")),
        MemeWallCaption(top: String(localized: "IL WI-FI È LENTO?"), bottom: String(localized: "PERFETTO PER UN PISOLINO")),
        MemeWallCaption(top: String(localized: "HO PERSO IL FILO"), bottom: String(localized: "DEL GOMITOLO. E DEL DISCORSO.")),
        MemeWallCaption(top: String(localized: "ANCORA SULLA TASTIERA?"), bottom: String(localized: "SPOSTATI. TOCCA A ME.")),
        MemeWallCaption(top: String(localized: "TI HO PORTATO UN REGALO"), bottom: String(localized: "È UN CALZINO. È TUO.")),
        MemeWallCaption(top: String(localized: "IL POMODORO È FINITO"), bottom: String(localized: "IO NON HO MAI INIZIATO")),
        MemeWallCaption(top: String(localized: "PRESENTAZIONE ALLE 15?"), bottom: String(localized: "SONNELLINO ALLE 15.")),
    ]

    static let tips: [MemeWallCaption] = [
        MemeWallCaption(top: String(localized: "BEVI UN BICCHIERE D'ACQUA"), bottom: String(localized: "IO HO GIÀ BEVUTO DAL TUO"), kind: .tip),
        MemeWallCaption(top: String(localized: "GUARDA LONTANO 20 SECONDI"), bottom: String(localized: "TIPO VERSO IL FRIGO"), kind: .tip),
        MemeWallCaption(top: String(localized: "STIRATI COME UN GATTO"), bottom: String(localized: "SCHIENA IN SU, ZAMPE AVANTI"), kind: .tip),
        MemeWallCaption(top: String(localized: "ALZATI, FAI DUE PASSI"), bottom: String(localized: "IO TI SEGUO. OVVIAMENTE."), kind: .tip),
        MemeWallCaption(top: String(localized: "SPALLE GIÙ, RESPIRA"), bottom: String(localized: "INSPIRA... ESPIRA... MIAO"), kind: .tip),
        MemeWallCaption(top: String(localized: "SBATTI LE PALPEBRE"), bottom: String(localized: "PIANO. COME UN GATTO CHE TI VUOLE BENE."), kind: .tip),
        MemeWallCaption(top: String(localized: "APRI LA FINESTRA"), bottom: String(localized: "ARIA FRESCA E UN PICCIONE DA FISSARE"), kind: .tip),
        MemeWallCaption(top: String(localized: "RUOTA IL COLLO PIANO"), bottom: String(localized: "DESTRA... SINISTRA... CROCCHETTA"), kind: .tip),
        MemeWallCaption(top: String(localized: "LONTANO DALLO SCHERMO"), bottom: String(localized: "LO SCHERMO NON SCAPPA"), kind: .tip),
    ]
}

/// Hands out captions without repeats: every caption is shown once before the bag is refilled,
/// and a caption that is on screen right now (on any display) is never handed out twice.
@MainActor
final class MemeWallDeck {
    private var bag: [Int] = []
    private var inUse = Set<Int>()

    /// Returns the index of the next caption in `MemeWallCaption.all`.
    func draw() -> Int {
        let count = MemeWallCaption.all.count
        if bag.isEmpty { refill() }
        var position = bag.firstIndex { !inUse.contains($0) }
        if position == nil {
            refill()
            position = bag.firstIndex { !inUse.contains($0) }
        }
        let index: Int
        if let position = position {
            index = bag.remove(at: position)
        } else {
            index = Int.random(in: 0..<count)
        }
        inUse.insert(index)
        return index
    }

    /// Marks a caption as no longer on screen.
    func release(_ index: Int) {
        inUse.remove(index)
    }

    private func refill() {
        bag = Array(MemeWallCaption.all.indices).filter { !inUse.contains($0) }.shuffled()
    }
}
