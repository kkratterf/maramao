import SwiftUI
import MaramaoCore

/// The panel that opens from the menu bar.
struct MenuContentView: View {
    @EnvironmentObject private var engine: PomodoroEngine
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: StatsStore
    @ObservedObject private var shortcuts = GlobalShortcuts.shared
    @ObservedObject private var availability = AvailabilityStore.shared
    @ObservedObject private var updater = AppUpdater.shared
    @ObservedObject private var companion = CatCompanionStore.shared
    @State private var treatReaction: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            timer
            if let notice = engine.awayNotice {
                awayRow(notice)
            }
            controls
            snoozeRow
            todayRow
            if settings.companionEnabled {
                companionRow
            }
            Divider()
            modePicker
            previewRow
            Divider()
            if updater.isAvailable {
                updateRow
            }
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 10) {
            CatView(pose: engine.phase.isBreak ? .sleeping : .sitting, palette: .orange)
                .frame(width: 44, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Maramao").font(.headline)
                Text(phaseTitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            sessionDots
        }
    }

    private var phaseTitle: String {
        if engine.isBreakSnoozed { return BreakSnoozeText.waiting }
        switch engine.phase {
        case .idle:
            if availability.isSnoozed { return String(localized: "Il gatto dorme \(availability.untilText())") }
            if !availability.isWorkingTime() { return String(localized: "Fuori orario: niente partenze automatiche") }
            return String(localized: "Pronto quando lo sei tu")
        case .work:
            if engine.isBreakPostponed { return String(localized: "Pausa in attesa: sei in call") }
            return engine.isPaused ? String(localized: "In pausa (tu, non il gatto)") : String(localized: "Concentrazione")
        case .shortBreak: return String(localized: "Pausa breve")
        case .longBreak: return String(localized: "Pausa lunga")
        }
    }

    private var sessionDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<settings.sessionsBeforeLongBreak, id: \.self) { i in
                Circle()
                    .fill(i < engine.sessionsInCurrentSet ? Color.orange : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .help("Pomodori completati in questo giro")
    }

    private var timer: some View {
        VStack(spacing: 6) {
            Text(formatClock(engine.remaining))
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .frame(maxWidth: .infinity)
            ProgressView(value: engine.progress)
                .tint(engine.phase.isBreak ? .purple : .orange)
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack {
            switch engine.phase {
            case .idle:
                Button("Inizia a lavorare") { engine.startWork() }
                    .keyboardShortcut(.defaultAction)
                    .help(String(localized: "Inizia un pomodoro") + shortcuts.hint(.startPause))
            case .work:
                Button(engine.isPaused ? LocalizedStringKey("Riprendi") : LocalizedStringKey("Pausa")) { engine.togglePause() }
                    .help((engine.isPaused ? String(localized: "Riprendi il pomodoro") : String(localized: "Metti in pausa il pomodoro")) + shortcuts.hint(.startPause))
                Button("Pausa gatto ora") { engine.takeBreakNow() }
                    .help(String(localized: "Fai subito la pausa") + shortcuts.hint(.takeBreak))
            case .shortBreak, .longBreak:
                if engine.isBreakSnoozed {
                    Button("Pausa gatto ora") { engine.takeBreakNow() }
                        .help(String(localized: "Fai subito la pausa") + shortcuts.hint(.takeBreak))
                } else if engine.canSnoozeBreak {
                    Button(BreakSnoozeText.button(minutes: settings.snoozePolicy.minutes)) { engine.snoozeBreak() }
                        .help(BreakSnoozeText.left(settings.snoozePolicy.snoozesLeft(usedToday: stats.today.breaksSnoozed)) + shortcuts.hint(.snooze))
                }
                Button("Salta pausa") { engine.skip() }
                    .disabled(!engine.canSkipBreak)
                    .help((settings.strictMode ? String(localized: "Modalità severa: non si salta") : String(localized: "Disponibile dopo \(Int(settings.skipUnlockSeconds)) secondi")) + shortcuts.hint(.skip))
            }
            Spacer()
            if engine.phase != .idle {
                Button {
                    engine.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Ricomincia da capo")
            }
        }
        .controlSize(.large)
    }

    /// "Bentornato! Ti sei già riposato", with a way to undo the guess.
    private func awayRow(_ notice: String) -> some View {
        HStack(spacing: 8) {
            Text("😺")
            Text(notice)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if engine.canUndoAwayReset {
                Button("Riprendi da dove ero") { engine.undoAwayReset() }
                    .font(.caption)
            }
            Button {
                engine.dismissAwayNotice()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Ok")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    /// "Pausa per…" while not in a break; "Riprendi ora" while snoozed.
    @ViewBuilder
    private var snoozeRow: some View {
        if availability.isSnoozed && engine.phase == .idle {
            HStack {
                Text("😴 Fermo \(availability.untilText())")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Riprendi ora") {
                    availability.endSnooze()
                    engine.startWork()
                }
            }
        } else if !engine.phase.isBreak {
            HStack {
                Menu {
                    ForEach(SnoozeOption.allCases) { option in
                        Button(option.title) { engine.snooze(option) }
                    }
                } label: {
                    Label("Pausa per…", systemImage: "moon.zzz")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Ferma Maramao per un po': riparte da solo")
                Spacer()
            }
        }
    }

    /// "Il tuo gatto": mood, treats and a button to give one.
    private var companionRow: some View {
        let cat = companion.companion
        return HStack(spacing: 8) {
            Text(cat.mood.emoji)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(treatReaction.map { "\(cat.name): \($0)" } ?? cat.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: "\(cat.mood.label) · \(CatCompanionText.treatsLine(cat.treats))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button {
                giveTreat()
            } label: {
                Label("Croccantino", systemImage: "fish")
            }
            .controlSize(.small)
            .disabled(!cat.canGiveTreat)
            .help(cat.canGiveTreat ? String(localized: "Dai un croccantino a \(cat.name)") : CatCompanionText.earnTreatHint)
        }
    }

    private func giveTreat() {
        guard let reaction = companion.giveTreat() else { return }
        treatReaction = reaction
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if treatReaction == reaction { treatReaction = nil }
        }
    }

    private var todayRow: some View {
        Text(stats.todayLine)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .help("Pomodori completati oggi, pause rispettate e giorni di fila con almeno un pomodoro")
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Come ti fermano i gatti").font(.caption).foregroundStyle(.secondary)
            Picker("Modalità", selection: $settings.breakModeRaw) {
                ForEach(BreakModeID.allCases) { mode in
                    Text("\(mode.emoji)  \(mode.title)").tag(mode.rawValue)
                }
            }
            .labelsHidden()
            Text(settings.breakMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var previewRow: some View {
        HStack {
            Text("Prova un concept").font(.caption).foregroundStyle(.secondary)
            Spacer()
            ForEach(BreakModeID.concrete) { mode in
                Button(mode.emoji) { engine.preview(mode, seconds: 30) }
                    .buttonStyle(.borderless)
                    .help(mode.title)
                    .disabled(engine.phase.isBreak)
            }
        }
    }

    /// Hidden until the build has a real Sparkle key (see `AppUpdater`).
    private var updateRow: some View {
        HStack {
            if let version = updater.pendingUpdateVersion {
                Button("🎁 Nuova versione \(version) disponibile") { updater.checkForUpdates() }
                    .foregroundStyle(.orange)
                    .help("Mostra l'aggiornamento")
            } else {
                Button("Controlla aggiornamenti…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                    .help("Cerca una nuova versione di Maramao")
            }
            Spacer()
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            Button("Impostazioni…") {
                (NSApp.delegate as? AppDelegate)?.showSettings()
            }
            Spacer()
            Button("Esci") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}
