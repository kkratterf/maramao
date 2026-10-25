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

    /// Built-in captions plus those of the enabled cat packs.
    static var all: [MemeWallCaption] { builtIn + CatPackRuntime.shared.content.captions }

    static let builtIn: [MemeWallCaption] = jokes + tips

    static let jokes: [MemeWallCaption] = [
        MemeWallCaption(top: "QUANDO DICI 'ANCORA UN'EMAIL'", bottom: "E IL GATTO DICE NO"),
        MemeWallCaption(top: "PAUSA?", bottom: "PAUSA."),
        MemeWallCaption(top: "HO CHIUSO IL TUO LAPTOP", bottom: "CON IL SEDERE"),
        MemeWallCaption(top: "IL TUO POMODORO È SCADUTO", bottom: "ORA SI FANNO LE FUSA"),
        MemeWallCaption(top: "TU: 'SONO PRODUTTIVO'", bottom: "IO: DORMO 16 ORE AL GIORNO"),
        MemeWallCaption(top: "LA RIUNIONE POTEVA ESSERE UN'EMAIL", bottom: "L'EMAIL POTEVA ESSERE UN PISOLINO"),
        MemeWallCaption(top: "CTRL+S", bottom: "CTRL+SONNELLINO"),
        MemeWallCaption(top: "HAI SCRITTO 'ASDFGHJKL'?", bottom: "NO, SONO PASSATO IO"),
        MemeWallCaption(top: "IL CODICE COMPILA?", bottom: "NON MI INTERESSA. CROCCHETTE."),
        MemeWallCaption(top: "25 MINUTI DI LAVORO", bottom: "5 MINUTI DI ME. NON TRATTABILE."),
        MemeWallCaption(top: "LA SCRIVANIA È MIA", bottom: "IL TUO MOUSE È UN GIOCATTOLO"),
        MemeWallCaption(top: "DEADLINE?", bottom: "MAI SENTITA"),
        MemeWallCaption(top: "STAVI LAVORANDO?", bottom: "CHE PECCATO"),
        MemeWallCaption(top: "IL BUG NON SPARISCE", bottom: "IO SÌ. SOTTO IL LETTO."),
        MemeWallCaption(top: "SEI IN CALL?", bottom: "PERFETTO, ARRIVO IN CAMERA"),
        MemeWallCaption(top: "TU GUARDI LO SCHERMO", bottom: "IO GUARDO TE. E GIUDICO."),
        MemeWallCaption(top: "HAI 47 TAB APERTE", bottom: "IO ZERO. E STO BENISSIMO."),
        MemeWallCaption(top: "OGNI POMODORO", bottom: "MERITA UN GRATTINO"),
        MemeWallCaption(top: "NON È PIGRIZIA", bottom: "È RISPARMIO ENERGETICO"),
        MemeWallCaption(top: "LA TASTIERA È CALDA", bottom: "QUINDI È UN LETTO"),
        MemeWallCaption(top: "MULTITASKING:", bottom: "DORMIRE E GIUDICARTI INSIEME"),
        MemeWallCaption(top: "'FINISCO SOLO QUESTA COSA'", bottom: "SONO 3 POMODORI CHE LO DICI"),
        MemeWallCaption(top: "HO MESSO LA ZAMPA SU INVIO", bottom: "SPERO NON FOSSE IMPORTANTE"),
        MemeWallCaption(top: "IL TUO CAPO TI CERCA", bottom: "IL TUO GATTO TI HA TROVATO"),
        MemeWallCaption(top: "NIENTE NOTIFICHE", bottom: "SOLO MIAGOLII"),
        MemeWallCaption(top: "MODALITÀ FOCUS", bottom: "SULLA CIOTOLA VUOTA"),
        MemeWallCaption(top: "PRIMA LA PAUSA", bottom: "POI LA PAUSA"),
        MemeWallCaption(top: "PRODUTTIVITÀ: 0%", bottom: "MORBIDEZZA: 100%"),
        MemeWallCaption(top: "IL FILE ERA SALVATO?", bottom: "ORMAI È TARDI"),
        MemeWallCaption(top: "HO LETTO IL TUO CODICE", bottom: "MI SERVE UN PISOLINO"),
        MemeWallCaption(top: "SEI STANCO?", bottom: "ANCH'IO. E NON HO FATTO NIENTE."),
        MemeWallCaption(top: "UNA SCATOLA DI CARTONE", bottom: "MEGLIO DI QUALSIASI UFFICIO"),
        MemeWallCaption(top: "LA SEDIA ERA TUA", bottom: "ERA."),
        MemeWallCaption(top: "IL TIMER SUONA", bottom: "IO MIAGOLO PIÙ FORTE"),
        MemeWallCaption(top: "BACKUP FATTO?", bottom: "IO HO FATTO LE FUSA"),
        MemeWallCaption(top: "UN ALTRO CAFFÈ?", bottom: "UN ALTRO PISOLINO."),
        MemeWallCaption(top: "QUANDO IL TIMER FA DRIN", bottom: "E TU FAI FINTA DI NIENTE"),
        MemeWallCaption(top: "LAVORI DA CASA?", bottom: "NO. LAVORI A CASA MIA."),
        MemeWallCaption(top: "'DOMANI LO FINISCO'", bottom: "MOTTO UFFICIALE DEI GATTI"),
        MemeWallCaption(top: "TO-DO LIST: 1. DORMIRE", bottom: "2. DORMIRE DI NUOVO"),
        MemeWallCaption(top: "L'ALGORITMO È SEMPLICE", bottom: "SE C'È SOLE, CI DORMO"),
        MemeWallCaption(top: "STANDUP MEETING?", bottom: "IO SONO SDRAIATO, GRAZIE"),
        MemeWallCaption(top: "GIT COMMIT", bottom: "ALLA SIESTA"),
        MemeWallCaption(top: "VAI IN PAUSA", bottom: "O LA TAZZA CADE DAL TAVOLO"),
        MemeWallCaption(top: "IL WI-FI È LENTO?", bottom: "PERFETTO PER UN PISOLINO"),
        MemeWallCaption(top: "HO PERSO IL FILO", bottom: "DEL GOMITOLO. E DEL DISCORSO."),
        MemeWallCaption(top: "ANCORA SULLA TASTIERA?", bottom: "SPOSTATI. TOCCA A ME."),
        MemeWallCaption(top: "TI HO PORTATO UN REGALO", bottom: "È UN CALZINO. È TUO."),
        MemeWallCaption(top: "IL POMODORO È FINITO", bottom: "IO NON HO MAI INIZIATO"),
        MemeWallCaption(top: "PRESENTAZIONE ALLE 15?", bottom: "SONNELLINO ALLE 15."),
    ]

    static let tips: [MemeWallCaption] = [
        MemeWallCaption(top: "BEVI UN BICCHIERE D'ACQUA", bottom: "IO HO GIÀ BEVUTO DAL TUO", kind: .tip),
        MemeWallCaption(top: "GUARDA LONTANO 20 SECONDI", bottom: "TIPO VERSO IL FRIGO", kind: .tip),
        MemeWallCaption(top: "STIRATI COME UN GATTO", bottom: "SCHIENA IN SU, ZAMPE AVANTI", kind: .tip),
        MemeWallCaption(top: "ALZATI, FAI DUE PASSI", bottom: "IO TI SEGUO. OVVIAMENTE.", kind: .tip),
        MemeWallCaption(top: "SPALLE GIÙ, RESPIRA", bottom: "INSPIRA... ESPIRA... MIAO", kind: .tip),
        MemeWallCaption(top: "SBATTI LE PALPEBRE", bottom: "PIANO. COME UN GATTO CHE TI VUOLE BENE.", kind: .tip),
        MemeWallCaption(top: "APRI LA FINESTRA", bottom: "ARIA FRESCA E UN PICCIONE DA FISSARE", kind: .tip),
        MemeWallCaption(top: "RUOTA IL COLLO PIANO", bottom: "DESTRA... SINISTRA... CROCCHETTA", kind: .tip),
        MemeWallCaption(top: "LONTANO DALLO SCHERMO", bottom: "LO SCHERMO NON SCAPPA", kind: .tip),
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
