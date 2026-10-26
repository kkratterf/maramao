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
                HStack {
                    Text("Il gatto ti rispiega tutto e ti fa provare una pausa.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Rivedi il benvenuto") {
                        (NSApp.delegate as? AppDelegate)?.showOnboarding()
                    }
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
                Picker("Quando sei via", selection: $settings.awayBehaviorRaw) {
                    ForEach(AwayBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior.rawValue)
                    }
                }
                Text(awayCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                Picker("Schermi", selection: $settings.displayScopeRaw) {
                    ForEach(DisplayScope.allCases, id: \.self) { scope in
                        Text(scope.label).tag(scope.rawValue)
                    }
                }
                Text("Gli schermi senza gatti vengono solo un po' oscurati. Il gatto sulla finestra segue sempre la finestra attiva.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

            CatCompanionSection()

            CatPacksSettingsSection()

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

            Section("Call e presentazioni") {
                Toggle("Non interrompere call e presentazioni", isOn: $settings.dontInterruptCalls)
                if settings.dontInterruptCalls {
                    Picker("Rimanda la pausa", selection: $settings.maxPostponeMinutes) {
                        ForEach(BreakPostponer.maxMinutesOptions, id: \.self) { minutes in
                            Text(BreakPostponer.maxLabel(minutes: minutes)).tag(minutes)
                        }
                    }
                }
                Text("Se il microfono o la videocamera sono in uso, o hai a tutto schermo Keynote, PowerPoint, un video o una call, la pausa aspetta un minuto alla volta. Nessun permesso richiesto.")
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
                if !settings.strictMode {
                    Picker("Rimanda la pausa", selection: $settings.snoozeDailyLimit) {
                        ForEach(BreakSnoozePolicy.dailyLimitOptions, id: \.self) { limit in
                            Text(BreakSnoozeText.limitLabel(limit)).tag(limit)
                        }
                    }
                    if settings.snoozeDailyLimit > 0 {
                        Picker("Di quanto", selection: $settings.snoozeMinutes) {
                            ForEach(BreakSnoozePolicy.minuteOptions, id: \.self) { minutes in
                                Text(BreakSnoozeText.minutesLabel(minutes)).tag(minutes)
                            }
                        }
                        Text("\"Rimanda\" compare nella prima metà della pausa: il gatto se ne va e torna dopo, con la pausa intera. Non è \"Pausa per…\", che addormenta tutta l'app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                Text(verbatim: "Maramao \(appVersion) · MIT · github.com/kkratterf/maramao")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Text("Copia versione, macOS, schermi, impostazioni e le ultime righe del log, senza dati personali, e apre su GitHub una segnalazione già compilata. Non parte niente finché non la invii tu.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Segnala un problema…") { BugReporter.reportProblem() }
                }
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

    /// Explains the "Quando sei via" choice.
    private var awayCaption: String {
        let minutes = Int(AwayPolicy.idleThreshold(shortBreak: settings.shortBreakMinutes * 60) / 60)
        let away = String(localized: "Mac in stop, schermo bloccato o \(minutes) min senza toccare niente.")
        switch AwayBehavior(rawValue: settings.awayBehaviorRaw) ?? .defaultBehavior {
        case .countAsBreak:
            return away + " " + String(localized: "Il timer si ferma e, se sei stato via almeno una pausa breve, al ritorno riparti da capo: la pausa l'hai già fatta.")
        case .pause:
            return away + " " + String(localized: "Il timer si ferma e ti aspetta in pausa finché non riprendi tu.")
        case .ignore:
            return String(localized: "Il timer continua a correre, ma la pausa non parte mai a schermo bloccato: aspetta che torni.")
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
            launchAtLoginError = String(localized: "Non riesco a cambiare l'avvio automatico: \(error.localizedDescription)")
            refreshLaunchAtLogin()
        }
    }

    private func minutesStepper(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            Text("\(Text(title)): \(Int(value.wrappedValue)) min")
        }
    }
}
