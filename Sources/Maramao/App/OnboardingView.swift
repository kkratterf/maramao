import SwiftUI
import MaramaoCore

/// The welcome window's content: a cat introduces Maramao in a few skippable steps.
/// Hosted in a plain NSWindow by `AppDelegate.showOnboarding()`.
struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: PomodoroEngine
    /// Closes the window. The window's owner marks onboarding as done.
    let onClose: () -> Void

    @State private var step: OnboardingStep = .first
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?
    @State private var launchAtLoginNeedsApproval = false

    var body: some View {
        VStack(spacing: 16) {
            CatView(pose: catPose, palette: .orange, eyesClosed: step == .launchAtLogin)
                .frame(width: 150, height: 120)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(24)
        .frame(width: 460, height: 480)
        .onAppear(perform: refreshLaunchAtLogin)
    }

    private var catPose: CatPose {
        switch step {
        case .welcome, .cat, .emergencyExit: return .sitting
        case .timing, .trial: return .stretching
        case .launchAtLogin: return .sleeping
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            title("Ciao, sono Maramao")
            paragraph("Vivo nella barra dei menu, lassù accanto all'orologio: clicca il mio musetto per avviare il timer. Quando il pomodoro finisce, un gatto si prende lo schermo finché non fai una pausa.")
            paragraph("Non vedi il mio musetto lassù? La barra è troppo piena e la tacca dello schermo mi copre: togli qualche icona, oppure riapri Maramao dalla cartella Applicazioni e ti apro una finestra.")
            paragraph("Non è un virus: è per il tuo bene.")
        case .timing:
            title("Quanto lavori, quanto riposi")
            paragraph("Il classico è 25 minuti di lavoro e 5 di pausa. Puoi cambiarli quando vuoi nelle Impostazioni.")
            minutesStepper("Lavoro", value: $settings.workMinutes, range: 1...120)
            minutesStepper("Pausa breve", value: $settings.shortBreakMinutes, range: 1...30)
        case .cat:
            title("Scegli il tuo gatto")
            paragraph("Chi ti ferma quando è ora di staccare? Con Sorpresa ogni pausa è diversa.")
            Picker("Modalità pausa", selection: $settings.breakModeRaw) {
                ForEach(BreakModeID.allCases) { mode in
                    Text("\(mode.emoji)  \(mode.title)").tag(mode.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Text(settings.breakMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .trial:
            title("Prova una pausa")
            paragraph("Dura solo \(Int(OnboardingStep.trialBreakSeconds)) secondi, poi il gatto se ne va. Così la prima pausa vera non ti coglie di sorpresa.")
            Button("Fammi vedere") {
                engine.preview(settings.breakMode, seconds: OnboardingStep.trialBreakSeconds)
            }
            .controlSize(.large)
            .disabled(engine.phase.isBreak || engine.activeBreakMode != nil)
        case .emergencyExit:
            title("L'uscita di emergenza")
            paragraph("Se proprio devi scappare, \(EmergencyExitGuard.shortcutLabel) chiude subito qualsiasi pausa, anche in modalità severa.")
            Text(verbatim: EmergencyExitGuard.shortcutLabel)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
            paragraph("Oppure clicca \(EmergencyExitGuard.cornerClicks) volte di fila nell'angolo in alto a sinistra dello schermo. Il gatto ci rimane male, ma ti lascia andare.")
        case .launchAtLogin:
            title("Sempre con te")
            paragraph("Se vuoi, mi apro all'avvio del Mac, così non ti scordi mai le pause.")
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
            Text("Puoi rivedere questo benvenuto quando vuoi dalle Impostazioni.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            if step.isLast {
                Button("Più tardi", action: onClose)
            } else {
                Button("Salta", action: onClose)
            }
            Spacer()
            dots
            Spacer()
            if let previous = step.previous {
                Button("Indietro") { step = previous }
            }
            if let next = step.next {
                Button("Avanti") { step = next }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Inizia il primo pomodoro") {
                    if engine.phase == .idle { engine.startWork() }
                    onClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Circle()
                    .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Passo \(step.number) di \(OnboardingStep.allCases.count)"))
    }

    // MARK: - Building blocks

    private func title(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.title2.bold())
    }

    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }

    private func minutesStepper(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            Text("\(Text(title)): \(Int(value.wrappedValue)) min")
        }
    }

    // MARK: - Launch at login

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
        } catch {
            launchAtLoginError = String(localized: "Non riesco a cambiare l'avvio automatico: \(error.localizedDescription)")
        }
        refreshLaunchAtLogin()
    }
}
