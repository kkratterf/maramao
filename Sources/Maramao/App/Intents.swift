import AppIntents
import MaramaoCore

// Shortcuts actions. Each one runs the same `AutomationCommand` as the
// matching maramao:// URL, without opening any window.

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Inizia un pomodoro"
    static let description: IntentDescription? = IntentDescription("Fa partire un pomodoro, o lo riprende se è in pausa.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AutomationRunner.perform(.start)
        return .result()
    }
}

struct PauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Metti in pausa o riprendi"
    static let description: IntentDescription? = IntentDescription("Mette in pausa il pomodoro in corso, o lo riprende.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AutomationRunner.perform(.toggle)
        return .result()
    }
}

struct TakeBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Pausa gatto ora"
    static let description: IntentDescription? = IntentDescription("Finisce il pomodoro e fa partire subito la pausa coi gatti.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AutomationRunner.perform(.takeBreak)
        return .result()
    }
}

/// Break modes for the "Scegli la modalità pausa" action. Kept apart from
/// `FocusFilterBreakMode` on purpose: that one adds `unchanged`, which means nothing
/// for an action that sets a mode, and App Intents reads these display names at
/// compile time, so they must stay literal constants rather than a shared table.
/// Raw values must match `BreakModeID`.
enum BreakModeAppEnum: String, AppEnum {
    case walkingCat
    case memeWall
    case sleepyCat
    case catPile
    case laserChase
    case keyboardCat
    case random

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Modalità pausa"
    static let caseDisplayRepresentations: [BreakModeAppEnum: DisplayRepresentation] = [
        .walkingCat: "Il gatto sulla finestra",
        .memeWall: "Muro di meme",
        .sleepyCat: "Non svegliare il gatto",
        .catPile: "Invasione di gatti",
        .laserChase: "Caccia al laser",
        .keyboardCat: "Il gatto sulla tastiera",
        .random: "Sorpresa",
    ]
}

struct SetBreakModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Scegli la modalità pausa"
    static let description: IntentDescription? = IntentDescription("Sceglie come i gatti ti fermeranno alla prossima pausa.")

    @Parameter(title: "Modalità")
    var mode: BreakModeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        AutomationRunner.perform(.setMode(mode.rawValue))
        return .result()
    }
}

/// The same modes plus "same as the short break", for the long-break action.
/// Raw values must match `BreakModeID`, except `same`.
enum LongBreakModeAppEnum: String, AppEnum {
    case same
    case walkingCat
    case memeWall
    case sleepyCat
    case catPile
    case laserChase
    case keyboardCat
    case random

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Gatto della pausa lunga"
    static let caseDisplayRepresentations: [LongBreakModeAppEnum: DisplayRepresentation] = [
        .same: "Come la pausa breve",
        .walkingCat: "Il gatto sulla finestra",
        .memeWall: "Muro di meme",
        .sleepyCat: "Non svegliare il gatto",
        .catPile: "Invasione di gatti",
        .laserChase: "Caccia al laser",
        .keyboardCat: "Il gatto sulla tastiera",
        .random: "Sorpresa",
    ]
}

struct SetLongBreakModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Scegli il gatto della pausa lunga"
    static let description: IntentDescription? = IntentDescription("Sceglie come i gatti ti fermeranno alla prossima pausa lunga.")

    @Parameter(title: "Modalità")
    var mode: LongBreakModeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        let id = mode == .same ? AutomationCommand.sameAsShortBreak : mode.rawValue
        AutomationRunner.perform(.setLongBreakMode(id))

/// Rhythms for the "Scegli il ritmo" action. Literal display names, like
/// `BreakModeAppEnum`. Raw values must match `TimerPreset`.
enum TimerPresetAppEnum: String, AppEnum {
    case classic
    case long
    case deep
    case custom

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Ritmo"
    static let caseDisplayRepresentations: [TimerPresetAppEnum: DisplayRepresentation] = [
        .classic: "Classico 25/5",
        .long: "Lungo 50/10",
        .deep: "Profondo 90/20",
        .custom: "Personalizzato",
    ]
}

struct SetTimerPresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Scegli il ritmo"
    static let description: IntentDescription? = IntentDescription("Cambia la durata di pomodoro e pause: Classico, Lungo, Profondo o i tempi delle Impostazioni.")

    @Parameter(title: "Ritmo")
    var preset: TimerPresetAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        AutomationRunner.perform(.setPreset(preset.rawValue))
        return .result()
    }
}

struct GetStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stato di Maramao"
    static let description: IntentDescription? = IntentDescription("Dice la fase attuale, il tempo rimasto e i pomodori di oggi.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        return .result(value: AutomationRunner.statusLine())
    }
}

struct MaramaoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Inizia un pomodoro con \(.applicationName)",
                "Avvia \(.applicationName)",
            ]
        )
        AppShortcut(
            intent: PauseIntent(),
            phrases: ["Metti in pausa \(.applicationName)"]
        )
        AppShortcut(
            intent: TakeBreakIntent(),
            phrases: ["Pausa gatto con \(.applicationName)"]
        )
        AppShortcut(
            intent: GetStatusIntent(),
            phrases: ["Stato di \(.applicationName)"]
        )
    }
}
