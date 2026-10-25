import SwiftUI
import MaramaoCore

/// Settings → "Orario di lavoro": days and hours when Maramao may start sessions on its own.
struct WorkingHoursSection: View {
    @ObservedObject private var availability = AvailabilityStore.shared

    var body: some View {
        Section("Orario di lavoro") {
            Toggle("Rispetta un orario di lavoro", isOn: $availability.workingHours.isEnabled)
            if availability.workingHours.isEnabled {
                HStack(spacing: 6) {
                    Text("Giorni")
                    Spacer()
                    ForEach(WorkingHours.weekdaysMondayFirst, id: \.self) { weekday in
                        dayToggle(weekday)
                    }
                }
                DatePicker("Dalle", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Alle", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                Text("Fuori orario la ripartenza automatica dopo la pausa è spenta e \"Pausa per…\" non fa ripartire il timer. \(AvailabilityText.summary(availability.workingHours)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func dayToggle(_ weekday: Int) -> some View {
        let isOn = availability.workingHours.weekdays.contains(weekday)
        return Button {
            if isOn {
                availability.workingHours.weekdays.remove(weekday)
            } else {
                availability.workingHours.weekdays.insert(weekday)
            }
        } label: {
            Text(AvailabilityText.weekdayInitial(weekday))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(width: 22, height: 22)
                .background(Circle().fill(isOn ? Color.orange : Color.secondary.opacity(0.15)))
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .help(AvailabilityText.weekdayName(weekday))
    }

    /// Bridges "minutes after midnight" to the Date a DatePicker wants (today at that time).
    private func timeBinding(_ keyPath: WritableKeyPath<WorkingHours, Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let minute = availability.workingHours[keyPath: keyPath]
                let today = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: today) ?? today
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                availability.workingHours[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
