import SwiftUI
import MaramaoCore

/// The panel that opens from the menu bar.
struct MenuContentView: View {
    @EnvironmentObject private var engine: PomodoroEngine
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var stats: StatsStore
    @ObservedObject private var shortcuts = GlobalShortcuts.shared
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            timer
            controls
            todayRow
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
        switch engine.phase {
        case .idle: return "Pronto quando lo sei tu"
        case .work: return engine.isPaused ? "In pausa (tu, non il gatto)" : "Concentrazione"
        case .shortBreak: return "Pausa breve"
        case .longBreak: return "Pausa lunga"
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
                    .help("Inizia un pomodoro" + shortcuts.hint(.startPause))
            case .work:
                Button(engine.isPaused ? "Riprendi" : "Pausa") { engine.togglePause() }
                    .help((engine.isPaused ? "Riprendi il pomodoro" : "Metti in pausa il pomodoro") + shortcuts.hint(.startPause))
                Button("Pausa gatto ora") { engine.takeBreakNow() }
                    .help("Fai subito la pausa" + shortcuts.hint(.takeBreak))
            case .shortBreak, .longBreak:
                Button("Salta pausa") { engine.skip() }
                    .disabled(!engine.canSkipBreak)
                    .help((settings.strictMode ? "Modalità severa: non si salta" : "Disponibile dopo \(Int(settings.skipUnlockSeconds)) secondi") + shortcuts.hint(.skip))
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
