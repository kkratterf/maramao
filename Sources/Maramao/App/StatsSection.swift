import SwiftUI
import MaramaoCore

/// The "Statistiche" section of Settings: last 7 days as bars, weekly totals, reset.
struct StatsSection: View {
    @ObservedObject var stats: StatsStore
    @Binding var confirmReset: Bool

    var body: some View {
        let week = stats.lastDays(7)
        let total = stats.total(ofLast: 7)
        VStack(alignment: .leading, spacing: 10) {
            Text(stats.todayLine)
                .font(.callout)
            WeekBars(days: week, labels: week.map { stats.weekdayLabel(for: $0.day) })
                .frame(height: 96)
            Text(weekSummary(total))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !total.modes.isEmpty {
                modesRow(total)
            }
            HStack {
                Spacer()
                Button("Azzera statistiche…", role: .destructive) { confirmReset = true }
                    .disabled(stats.stats.days.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekSummary(_ total: DayStats) -> String {
        let pomodori = pomodoriCount(total.workSessions)
        let focus = StatsText.duration(minutes: total.focusMinutes)
        var text = String(localized: "Ultimi 7 giorni: \(pomodori) · \(focus) di concentrazione")
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
}

/// Seven small bars, one per day, height = completed pomodori.
private struct WeekBars: View {
    let days: [DayStats]
    /// One weekday label per day, same order as `days`.
    let labels: [String]

    var body: some View {
        let maxValue = max(1, days.map(\.workSessions).max() ?? 0)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = index == days.count - 1
                VStack(spacing: 4) {
                    Text(day.workSessions > 0 ? "\(day.workSessions)" : "")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(height: 12)
                    GeometryReader { geo in
                        let fraction = CGFloat(day.workSessions) / CGFloat(maxValue)
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isToday ? Color.orange : Color.orange.opacity(0.55))
                                .frame(height: max(3, geo.size.height * fraction))
                                .opacity(day.workSessions > 0 ? 1 : 0.25)
                        }
                    }
                    Text(index < labels.count ? labels[index] : "")
                        .font(.caption2)
                        .fontWeight(isToday ? .semibold : .regular)
                        .foregroundStyle(isToday ? Color.primary : Color.secondary)
                        .frame(height: 12)
                }
                .frame(maxWidth: .infinity)
                .help(barHelp(day))
            }
        }
    }

    private func barHelp(_ day: DayStats) -> String {
        let pomodori = pomodoriCount(day.workSessions)
        let focus = StatsText.duration(minutes: day.focusMinutes)
        let breaks = String(localized: "\(day.breaksCompleted)/\(day.breaksTotal) pause rispettate")
        return "\(day.day): \(pomodori), \(focus), \(breaks)"
    }
}

/// "1 pomodoro", "4 pomodori" (plural variants in the String Catalog).
private func pomodoriCount(_ count: Int) -> String {
    String(localized: "\(count) pomodori")
}
