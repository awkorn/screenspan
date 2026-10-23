import FamilyControls
import SwiftUI

struct ScheduleDraft: Identifiable {
    let schedule: BlockSchedule
    let isNew: Bool
    var id: UUID { schedule.id }
}

struct LimitDraft: Identifiable {
    let limit: AppLimit
    let isNew: Bool
    var id: UUID { limit.id }
}

/// Create or change a schedule. Under strict mode a running schedule is
/// read-only until it ends, so editing can't be used to end it early.
struct ScheduleEditor: View {
    let draft: ScheduleDraft
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var schedule: BlockSchedule
    @State private var confirmsDelete = false

    init(draft: ScheduleDraft) {
        self.draft = draft
        _schedule = State(initialValue: draft.schedule)
    }

    private var isLocked: Bool { !draft.isNew && !blocking.canTurnOff(draft.schedule) }

    var body: some View {
        NavigationStack {
            Form {
                if isLocked {
                    Section {
                        Label("Strict mode is on. You can change this schedule after it ends.", systemImage: "lock.fill")
                            .font(.geist(size: 14))
                    }
                }
                Section {
                    TextField("Name", text: $schedule.name)
                        .font(.geist(size: 17, weight: .semibold))
                    if draft.isNew {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(BlockSchedule.presets) { preset in
                                    Button(preset.name) {
                                        schedule.name = preset.name
                                        schedule.startMinute = preset.startMinute
                                        schedule.endMinute = preset.endMinute
                                        schedule.weekdays = preset.weekdays
                                    }
                                    .font(.geist(size: 13, weight: .semibold))
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                Section {
                    DatePicker("Starts", selection: time(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: time(\.endMinute), displayedComponents: .hourAndMinute)
                } footer: {
                    Text(timeFooter)
                }
                Section("Repeats on") {
                    WeekdayPicker(selection: $schedule.weekdays)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                if !draft.isNew {
                    Section {
                        Button("Delete schedule", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .font(.geist(size: 16))
            .disabled(isLocked)
            .navigationTitle(draft.isNew ? "New schedule" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        schedule.name = schedule.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if schedule.name.isEmpty { schedule.name = "Schedule" }
                        blocking.save(schedule)
                        dismiss()
                    }
                    .disabled(!schedule.isValid || isLocked)
                }
            }
            .confirmationDialog("Delete \(schedule.name)?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    blocking.delete(draft.schedule)
                    dismiss()
                }
            }
        }
        .tint(Color(hex: "#0063D6"))
        .screenSpanLightSurface()
    }

    private var timeFooter: String {
        if schedule.weekdays.isEmpty { return "Pick at least one day." }
        if schedule.durationMinutes < BlockSchedule.minimumMinutes { return "Schedules need to last at least 15 minutes." }
        if schedule.durationMinutes >= 24 * 60 { return "Pick different start and end times." }
        let length = BlockingView.format(minutes: schedule.durationMinutes)
        return schedule.isOvernight
            ? "Blocks your distracting apps for \(length), ending the next morning."
            : "Blocks your distracting apps for \(length)."
    }

    private func time(_ keyPath: WritableKeyPath<BlockSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = schedule[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                schedule[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let names = Calendar.current.weekdaySymbols
        HStack(spacing: 6) {
            ForEach(BlockSchedule.orderedWeekdays(), id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? .white : OnboardingStyle.navy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(isOn ? OnboardingStyle.navy : OnboardingStyle.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Create or change a daily limit: which apps, and how long each day.
struct LimitEditor: View {
    let draft: LimitDraft
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @State private var limit: AppLimit
    @State private var showsPicker = false
    @State private var confirmsDelete = false

    private static let allowances = [15, 30, 45, 60, 90, 120, 180, 240]

    init(draft: LimitDraft) {
        self.draft = draft
        _limit = State(initialValue: draft.limit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showsPicker = true } label: {
                        HStack {
                            if limit.selection.isEmpty {
                                Label("Choose apps", systemImage: "plus.app")
                                    .font(.geist(size: 16, weight: .semibold))
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    SelectionIcons(selection: limit.selection, size: 28)
                                    Text(limit.selection.summary)
                                        .font(.geist(size: 13))
                                        .foregroundStyle(ScreenSpanAppearance.secondaryText)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#9AA3AE"))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Apps")
                }
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(Self.allowances, id: \.self) { minutes in
                            let isOn = limit.dailyMinutes == minutes
                            Button { limit.dailyMinutes = minutes } label: {
                                Text(BlockingView.format(minutes: minutes))
                                    .font(.geist(size: 14, weight: .semibold))
                                    .foregroundStyle(isOn ? .white : OnboardingStyle.navy)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(isOn ? OnboardingStyle.navy : OnboardingStyle.card,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Each day")
                } footer: {
                    Text("Time on all of these counts together. Once \(BlockingView.format(minutes: limit.dailyMinutes)) is used, they’re blocked until midnight.")
                }
                if !draft.isNew {
                    Section {
                        Button("Delete limit", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .font(.geist(size: 16))
            .navigationTitle(draft.isNew ? "New daily limit" : "Edit daily limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        blocking.save(limit)
                        dismiss()
                    }
                    .disabled(limit.selection.isEmpty)
                }
            }
            .familyActivityPicker(headerText: "Choose the apps that share this daily limit.",
                                  isPresented: $showsPicker, selection: $limit.selection)
            .confirmationDialog("Delete this limit?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    blocking.delete(draft.limit)
                    dismiss()
                }
            }
            .task {
                if draft.isNew {
                    try? await Task.sleep(for: .milliseconds(400))
                    showsPicker = true
                }
            }
        }
        .tint(Color(hex: "#0063D6"))
        .screenSpanLightSurface()
    }
}
