import SwiftUI
import MaramaoCore

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: PomodoroEngine
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?
    @State private var launchAtLoginNeedsApproval = false
    @EnvironmentObject private var stats: StatsStore
    @State private var confirmStatsReset = false
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        Form {
            Section("Generale") {
                Toggle("Apri Maramao all'avvio del Mac", isOn: launchAtLoginBinding)
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if launchAtLoginNeedsApproval {
                    Text("Consenti Maramao in Impostazioni di Sistema → Generale → Elementi login.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            MenuBarSettingsSection()

            Section("Tempi") {
                minutesStepper("Lavoro", value: $settings.workMinutes, range: 1...120)
                minutesStepper("Pausa breve", value: $settings.shortBreakMinutes, range: 1...30)
                minutesStepper("Pausa lunga", value: $settings.longBreakMinutes, range: 1...60)
                Stepper(value: $settings.sessionsBeforeLongBreak, in: 1...10) {
                    Text("Pausa lunga ogni \(settings.sessionsBeforeLongBreak) pomodori")
                }
                Toggle("Riparti a lavorare da solo dopo la pausa", isOn: $settings.autoStartWork)
            }

            WorkingHoursSection()

            Section("Gatti") {
                Picker("Modalità pausa", selection: $settings.breakModeRaw) {
                    ForEach(BreakModeID.allCases) { mode in
                        Text("\(mode.emoji)  \(mode.title)").tag(mode.rawValue)
                    }
                }
                Text(settings.breakMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Gatto che avvisa", selection: $settings.breakWarningSeconds) {
                    ForEach(BreakWarning.leadTimeOptions, id: \.self) { seconds in
                        Text(BreakWarning.optionLabel(seconds: seconds)).tag(seconds)
                    }
                }
                HStack {
                    Text("Un gattino sbuca dal bordo dello schermo poco prima della pausa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Prova") { engine.previewBreakWarning() }
                        .disabled(engine.phase.isBreak)
                }
            }

            Section("Accessibilità") {
                Picker("Animazioni delle pause", selection: $settings.motionPreferenceRaw) {
                    ForEach(MotionPreference.allCases, id: \.self) { preference in
                        Text(preference.label).tag(preference.rawValue)
                    }
                }
                Text("Con le animazioni ridotte i gatti appaiono con una dissolvenza: niente passeggiate, salti o gatti che cadono. \"Come il sistema\" segue Riduci movimento in Impostazioni di Sistema → Accessibilità → Schermo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Severità") {
                Toggle("Modalità severa: la pausa non si salta mai", isOn: $settings.strictMode)
                if !settings.strictMode {
                    Stepper(value: $settings.skipUnlockSeconds, in: 0...600, step: 15) {
                        Text("Pulsante \"Salta\" dopo \(Int(settings.skipUnlockSeconds)) secondi")
                    }
                }
                Text("Uscita di emergenza: \(EmergencyExitGuard.shortcutLabel) chiude subito qualsiasi pausa, anche in modalità severa. Funziona anche cliccando \(EmergencyExitGuard.cornerClicks) volte di fila nell'angolo in alto a sinistra dello schermo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Suoni") {
                Toggle("Suoni dei gatti", isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    HStack {
                        Text("Volume")
                        Slider(value: $settings.soundVolume, in: 0...1)
                    }
                    HStack {
                        Text("Prova i suoni")
                        Spacer()
                        Button("🐱 Miao") { CatSounds.shared.nextMeow() }
                        Button("😺 Fusa") { CatSounds.shared.purr(duration: 3) }
                        Button("🔔 Fine pausa") { CatSounds.shared.breakOverChime() }
                    }
                }
            }

            ShortcutsSettingsSection()

            AutomationsSection()

            Section("Statistiche") {
                StatsSection(stats: stats, confirmReset: $confirmStatsReset)
            }

            Section {
                Text("Le modifiche ai tempi valgono dal prossimo pomodoro.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if updater.isAvailable {
                Section("Aggiornamenti") {
                    Toggle("Aggiorna automaticamente", isOn: $updater.automaticallyChecksForUpdates)
                    HStack {
                        Text("Maramao controlla una volta al giorno se c'è una nuova versione e te la propone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("Controlla ora") { updater.checkForUpdates() }
                            .disabled(!updater.canCheckForUpdates)
                    }
                }
            }

            Section("Info") {
                Text("Maramao \(appVersion) · MIT · github.com/kkratterf/maramao")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .onAppear(perform: refreshLaunchAtLogin)
        .alert("Azzerare le statistiche?", isPresented: $confirmStatsReset) {
            Button("Azzera", role: .destructive) { stats.reset() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Pomodori, pause e giorni di fila verranno cancellati. Il gatto dimentica tutto.")
        }
    }

    /// Version from the bundle, or "dev" when running outside the .app.
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "dev"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding<Bool>(
            get: { launchAtLogin },
            set: { newValue in setLaunchAtLogin(newValue) }
        )
    }

    private func refreshLaunchAtLogin() {
        // "Requires approval" still counts as on: the user asked for it.
        launchAtLogin = LoginItem.isEnabled || LoginItem.requiresApproval
        launchAtLoginNeedsApproval = LoginItem.requiresApproval
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        do {
            try LoginItem.setEnabled(enabled)
            launchAtLoginError = nil
            refreshLaunchAtLogin()
        } catch {
            // Revert the toggle to the real state and explain why.
            launchAtLoginError = "Non riesco a cambiare l'avvio automatico: \(error.localizedDescription)"
            refreshLaunchAtLogin()
        }
    }

    private func minutesStepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            Text("\(title): \(Int(value.wrappedValue)) min")
        }
    }
}
