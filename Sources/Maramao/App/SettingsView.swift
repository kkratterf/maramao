import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Tempi") {
                minutesStepper("Lavoro", value: $settings.workMinutes, range: 1...120)
                minutesStepper("Pausa breve", value: $settings.shortBreakMinutes, range: 1...30)
                minutesStepper("Pausa lunga", value: $settings.longBreakMinutes, range: 1...60)
                Stepper(value: $settings.sessionsBeforeLongBreak, in: 1...10) {
                    Text("Pausa lunga ogni \(settings.sessionsBeforeLongBreak) pomodori")
                }
                Toggle("Riparti a lavorare da solo dopo la pausa", isOn: $settings.autoStartWork)
            }

            Section("Gatti") {
                Picker("Modalità pausa", selection: $settings.breakModeRaw) {
                    ForEach(BreakModeID.allCases) { mode in
                        Text("\(mode.emoji)  \(mode.title)").tag(mode.rawValue)
                    }
                }
                Text(settings.breakMode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Severità") {
                Toggle("Modalità severa: la pausa non si salta mai", isOn: $settings.strictMode)
                if !settings.strictMode {
                    Stepper(value: $settings.skipUnlockSeconds, in: 0...600, step: 15) {
                        Text("Pulsante \"Salta\" dopo \(Int(settings.skipUnlockSeconds)) secondi")
                    }
                }
                Toggle("Suoni", isOn: $settings.soundEnabled)
            }

            Section {
                Text("Le modifiche ai tempi valgono dal prossimo pomodoro.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
    }

    private func minutesStepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: value, in: range, step: 1) {
            Text("\(title): \(Int(value.wrappedValue)) min")
        }
    }
}
