import SwiftUI
import MaramaoCore

/// Settings → "Automazioni": a Shortcut per moment of the cycle.
struct AutomationsSection: View {
    @ObservedObject private var automations = ShortcutAutomations.shared

    var body: some View {
        Section("Automazioni") {
            Toggle("Esegui un Comando Rapido", isOn: $automations.isEnabled)
            if automations.isEnabled {
                ForEach(AutomationTrigger.allCases) { trigger in
                    row(trigger)
                }
                Text("Scrivi il nome di un comando dell'app Comandi Rapidi (es. \"Pausa musica\"). Riceve come input un piccolo JSON con evento, fase e gatto. Se il comando non esiste, Maramao lo ignora.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            if automations.isEnabled { automations.refreshAvailable() }
        }
        .onChange(of: automations.isEnabled) { enabled in
            if enabled { automations.refreshAvailable() }
        }
    }

    private func row(_ trigger: AutomationTrigger) -> some View {
        HStack {
            Text(trigger.title)
            Spacer()
            TextField("Nessuno", text: binding(trigger))
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)
            Menu {
                Button("Nessuno") { automations.setName("", for: trigger) }
                if !automations.available.isEmpty {
                    Divider()
                    ForEach(automations.available, id: \.self) { name in
                        Button(name) { automations.setName(name, for: trigger) }
                    }
                }
            } label: {
                Image(systemName: "list.bullet")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Scegli tra i tuoi Comandi Rapidi")
            Button("Prova") { automations.test(trigger) }
                .disabled(ShortcutCommand.cleanName(automations.name(for: trigger)) == nil)
        }
    }

    private func binding(_ trigger: AutomationTrigger) -> Binding<String> {
        Binding<String>(
            get: { automations.name(for: trigger) },
            set: { automations.setName($0, for: trigger) }
        )
    }
}
