import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers
import MaramaoCore

/// The "Statistiche" section of Settings: a bar chart of the last 7 or 30 days,
/// the totals of the period, the CSV export and the reset.
struct StatsSection: View {
    @ObservedObject var stats: StatsStore
    @Binding var confirmReset: Bool
    @State private var range: StatsRange = .week

    var body: some View {
        let days = stats.lastDays(range.days)
        let total = stats.total(ofLast: range.days)
        VStack(alignment: .leading, spacing: 10) {
            Text(stats.todayLine)
                .font(.callout)
            Picker("Periodo", selection: $range) {
                Text("7 giorni").tag(StatsRange.week)
                Text("30 giorni").tag(StatsRange.month)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            PomodoroChart(bars: bars(days))
                .frame(height: 120)
                // Thirty weekday labels do not fit: the period is in the summary below.
                .chartXAxis(range == .month ? .hidden : .visible)
            Text(periodSummary(total))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let best = stats.bestDay(ofLast: range.days) {
                Text(bestDayLine(best))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !total.modes.isEmpty {
                modesRow(total)
            }
            HStack {
                Button("Esporta CSV…") { exportCSV() }
                    .disabled(stats.stats.days.isEmpty)
                Spacer()
                Button("Azzera statistiche…", role: .destructive) { confirmReset = true }
                    .disabled(stats.stats.days.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Data

    private func bars(_ days: [DayStats]) -> [PomodoroBar] {
        days.enumerated().map { index, day in
            PomodoroBar(
                id: day.day,
                // On the 7-day chart the x axis shows weekdays; on the 30-day one it is hidden,
                // so the day key only has to stay unique.
                label: range == .week ? stats.weekdayLabel(for: day.day) : day.day,
                pomodori: day.workSessions,
                isLast: index == days.count - 1
            )
        }
    }

    private func periodSummary(_ total: DayStats) -> String {
        let pomodori = pomodoriCount(total.workSessions)
        let focus = StatsText.duration(minutes: total.focusMinutes)
        var text = String(localized: "Ultimi \(range.days) giorni: \(pomodori) · \(focus) di concentrazione")
        if total.breaksTotal > 0 {
            text += " · " + String(localized: "\(total.breaksCompleted)/\(total.breaksTotal) pause rispettate")
        }
        if total.breaksSnoozed > 0 {
            let snoozed = total.breaksSnoozed == 1
                ? String(localized: "1 pausa rimandata")
                : String(localized: "\(total.breaksSnoozed) pause rimandate")
            text += " · \(snoozed)"
        }
        if total.microBreaks > 0 {
            let micro = total.microBreaks == 1
                ? String(localized: "1 micro-pausa")
                : String(localized: "\(total.microBreaks) micro-pause")
            text += " · \(micro)"
        }
        if total.emergencyExits > 0 {
            let exits = String(localized: "\(total.emergencyExits) uscite di emergenza")
            text += " · \(exits)"
        }
        return text
    }

    private func bestDayLine(_ best: DayStats) -> String {
        let pomodori = pomodoriCount(best.workSessions)
        let active = stats.activeDays(ofLast: range.days)
        return String(localized: "Giorno migliore: \(best.day) con \(pomodori) · \(active) giorni attivi")
    }

    private func modesRow(_ total: DayStats) -> some View {
        HStack(spacing: 12) {
            ForEach(BreakModeID.concrete) { mode in
                if let counts = total.modes[mode.rawValue], counts.total > 0 {
                    Text("\(mode.emoji) \(counts.completed)/\(counts.total)")
                        .font(.caption.monospacedDigit())
                        .help("\(mode.title): \(counts.completed) pause rispettate su \(counts.total)")
                }
            }
            Spacer()
        }
    }

    // MARK: - Export

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Esporta le statistiche")
        panel.nameFieldStringValue = StatsCSV.fileName(for: Date())
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Data(stats.csv().utf8).write(to: url)
    }
}

/// One bar of the chart.
private struct PomodoroBar: Identifiable {
    let id: String
    /// What the x axis shows; unique inside the chart.
    let label: String
    let pomodori: Int
    /// Today, the right-most bar.
    let isLast: Bool
}

/// Pomodori per day as orange bars (Swift Charts, macOS 13+).
private struct PomodoroChart: View {
    let bars: [PomodoroBar]

    var body: some View {
        Chart(bars) { bar in
            BarMark(
                x: .value("Giorno", bar.label),
                y: .value("Pomodori", bar.pomodori)
            )
            .foregroundStyle(bar.isLast ? Color.orange : Color.orange.opacity(0.55))
        }
    }
}

/// "1 pomodoro", "4 pomodori" (plural variants in the String Catalog).
private func pomodoriCount(_ count: Int) -> String {
    String(localized: "\(count) pomodori")
}
