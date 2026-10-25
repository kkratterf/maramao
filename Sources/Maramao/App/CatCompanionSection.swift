import SwiftUI
import MaramaoCore

/// Settings → "Il tuo gatto": name the cat, see its mood and give it the treats you earned.
struct CatCompanionSection: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var store = CatCompanionStore.shared
    @State private var nameDraft = ""
    @State private var reaction: String?

    var body: some View {
        Section("Il tuo gatto") {
            Toggle("Un gatto che si ricorda di te", isOn: $settings.companionEnabled)
            if settings.companionEnabled {
                let cat = store.companion
                TextField("Nome", text: $nameDraft)
                    .onSubmit(commitName)
                LabeledContent("Umore") {
                    Text(CatCompanionText.moodLine(cat))
                }
                LabeledContent("Croccantini") {
                    HStack(spacing: 8) {
                        Text(CatCompanionText.treatsLine(cat.treats))
                        Button("Dai un croccantino") {
                            reaction = store.giveTreat()
                        }
                        .disabled(!cat.canGiveTreat)
                        .help(cat.canGiveTreat ? String(localized: "\(cat.name) ne sarà felice") : CatCompanionText.earnTreatHint)
                    }
                }
                if let reaction {
                    Text(verbatim: "\(cat.name): \(reaction)")
                        .font(.caption)
                }
                LabeledContent("Pause rispettate di fila") {
                    Text("\(cat.streak) (record \(cat.bestStreak))")
                }
                if let favourite = cat.favouriteMode.flatMap(BreakModeID.init(rawValue:)) {
                    LabeledContent("Concept preferito") {
                        Text(verbatim: "\(favourite.emoji) \(favourite.title)")
                    }
                }
                Text("Ogni pausa rispettata vale un croccantino (fino a \(CatCompanion.maxTreats)). Se salti una pausa il gatto ci resta un po' male, ma gli passa presto. Durante le pause puoi accarezzarlo con un clic e, nel gatto sulla finestra e nell'invasione di gatti, trascinarlo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { nameDraft = store.companion.name }
        .onDisappear(perform: commitName)
    }

    private func commitName() {
        guard settings.companionEnabled else { return }
        store.rename(nameDraft)
        nameDraft = store.companion.name
    }
}
