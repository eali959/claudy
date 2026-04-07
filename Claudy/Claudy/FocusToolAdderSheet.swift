import SwiftUI

/// Sheet for adding a new alarm or reminder from the character context menu.
struct FocusToolAdderSheet: View {
    enum ToolType: String, CaseIterable {
        case alarm    = "Alarm"
        case reminder = "Reminder"
    }

    @Binding var isPresented: Bool
    let manager: AlarmReminderManager

    @State private var toolType: ToolType
    @State private var title: String = ""
    @State private var date: Date = Date().addingTimeInterval(30 * 60)

    init(isPresented: Binding<Bool>, manager: AlarmReminderManager, defaultType: ToolType = .reminder) {
        self._isPresented = isPresented
        self.manager = manager
        self._toolType = State(initialValue: defaultType)
    }

    private var isAlarm: Bool { toolType == .alarm }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: isAlarm ? "alarm.fill" : "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.784, green: 0.361, blue: 0.220))
                Text(isAlarm ? "Set Alarm" : "New Reminder")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                // Type picker
                Picker("", selection: $toolType) {
                    ForEach(ToolType.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t == .alarm ? "alarm" : "checklist")
                            .tag(t)
                    }
                }
                .pickerStyle(.segmented)

                // Title field
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAlarm ? "Label (optional)" : "What to remind you")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(isAlarm ? "e.g. Stand up, check build…" : "e.g. Review PR, call back…", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                // Date / time picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("When")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }

                // Confirm button
                Button {
                    let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalTitle = label.isEmpty
                        ? (isAlarm ? "Alarm" : "Reminder")
                        : label
                    manager.add(title: finalTitle, fireDate: date)
                    isPresented = false
                } label: {
                    Label(isAlarm ? "Set Alarm" : "Set Reminder",
                          systemImage: isAlarm ? "alarm.fill" : "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.784, green: 0.361, blue: 0.220))
                .disabled(!isAlarm && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
