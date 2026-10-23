import FamilyControls
import SwiftUI

/// ScreenSpan Pro's blocking hub: start a focus block, choose the distraction
/// list, and manage schedules, daily limits, and strict mode.
struct BlockingView: View {
    /// Opens the app picker right away, for first-time setup after purchase.
    var opensPickerOnAppear = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocking: BlockingService
    @EnvironmentObject private var authService: AuthorizationService
    @State private var showsListPicker = false
    @State private var draftList = FamilyActivitySelection()
    @State private var sessionMinutes = 60
    @State private var editingSchedule: ScheduleDraft?
    @State private var editingLimit: LimitDraft?
    @State private var confirmsEndSession = false

    private var configuration: BlockingConfiguration { blocking.configuration }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !authService.isAuthorized { authorizationCard }
                    VStack(alignment: .leading, spacing: 28) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            if let session = configuration.activeSession(at: context.date) {
                                activeFocusCard(session, now: context.date)
                            } else {
                                startFocusCard
                            }
                        }
                        blockListSection
                        schedulesSection
                        limitsSection
                        strictModeSection
                    }
                    .disabled(!authService.isAuthorized)
                    .opacity(authService.isAuthorized ? 1 : 0.5)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Blocking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(OnboardingStyle.navy)
        .screenSpanLightSurface()
        .familyActivityPicker(headerText: "Choose the apps, categories, and sites that take your time.",
                              isPresented: $showsListPicker, selection: $draftList)
        .onChange(of: showsListPicker) { _, isShowing in
            if !isShowing { blocking.updateBlockList(draftList) }
        }
        .sheet(item: $editingSchedule) { draft in
            ScheduleEditor(draft: draft)
        }
        .sheet(item: $editingLimit) { draft in
            LimitEditor(draft: draft)
        }
        .alert("Couldn’t start blocking", isPresented: Binding(
            get: { blocking.errorMessage != nil },
            set: { if !$0 { blocking.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(blocking.errorMessage ?? "")
        }
        .confirmationDialog("End this focus block early?", isPresented: $confirmsEndSession, titleVisibility: .visible) {
            Button("End focus block", role: .destructive) { blocking.endSession() }
            Button("Keep going", role: .cancel) { }
        }
        .task {
            // Apply anything strict mode held until a midnight that has passed.
            blocking.reconcile()
            guard opensPickerOnAppear, authService.isAuthorized, configuration.blockList.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(450))
            openListPicker()
        }
    }

    // MARK: - Access

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Time access needed", systemImage: "lock")
                .font(.geist(size: 16, weight: .semibold))
            Text("Blocking uses Apple’s Screen Time controls. Allow access to choose and block apps.")
                .font(.geist(size: 14))
                .foregroundStyle(OnboardingStyle.muted)
            Button { Task { await authService.requestAuthorization() } } label: {
                Text("Allow Screen Time Access")
                    .font(.geist(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(OnboardingStyle.navy, in: Capsule())
            }
            .buttonStyle(.plain)
            if let message = authService.authorizationErrorMessage {
                Text(message).font(.geist(size: 12)).foregroundStyle(OnboardingStyle.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(hex: "#FDECEC"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Focus

    private var startFocusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Focus now")
                    .font(.geist(size: 22, weight: .bold))
                    .foregroundStyle(OnboardingStyle.navy)
                Text(configuration.blockList.isEmpty
                     ? "Choose your distracting apps, then block them for as long as you need."
                     : "Block \(configuration.blockList.summary) until you’re done.")
                    .font(.geist(size: 14))
                    .foregroundStyle(OnboardingStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                ForEach(BlockingService.sessionMinutes, id: \.self) { minutes in
                    Button {
                        withAnimation(.snappy) { sessionMinutes = minutes }
                    } label: {
                        Text(Self.format(minutes: minutes))
                            .font(.geist(size: 14, weight: .semibold))
                            .foregroundStyle(sessionMinutes == minutes ? .white : OnboardingStyle.navy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(sessionMinutes == minutes ? OnboardingStyle.navy : Color.white,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(sessionMinutes == minutes ? .isSelected : [])
                }
            }
            if configuration.blockList.isEmpty {
                OnboardingPrimaryButton(title: "Choose apps to block", action: openListPicker)
            } else {
                OnboardingPrimaryButton(title: "Start \(Self.format(minutes: sessionMinutes)) focus block") {
                    withAnimation(.snappy) { blocking.startSession(minutes: sessionMinutes) }
                }
            }
        }
        .padding(18)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func activeFocusCard(_ session: FocusSession, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: "#2BB673")).frame(width: 8, height: 8)
                Text("FOCUS BLOCK ON")
                    .font(.geist(size: 12, weight: .bold))
                    .tracking(0.8)
            }
            .foregroundStyle(.white.opacity(0.8))
            Text(timerInterval: now...max(now, session.end), countsDown: true)
                .font(.geist(size: 52, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("Ends at \(session.end.formatted(date: .omitted, time: .shortened)) · \(configuration.blockList.summary) blocked")
                .font(.geist(size: 14))
                .foregroundStyle(.white.opacity(0.75))
            if blocking.canEndSession {
                Button { confirmsEndSession = true } label: {
                    Text("End early")
                        .font(.geist(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Label("Strict mode is on. This block can’t end early.", systemImage: "lock.fill")
                    .font(.geist(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(OnboardingStyle.navy, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Block list

    private var blockListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Distracting apps", action: configuration.blockList.isEmpty ? nil : ("Edit", openListPicker))
            Button(action: openListPicker) {
                HStack(spacing: 12) {
                    if configuration.blockList.isEmpty {
                        Image(systemName: "plus.app")
                            .font(.system(size: 22))
                            .foregroundStyle(OnboardingStyle.red)
                        Text("Choose the apps that take your time")
                            .font(.geist(size: 15, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.navy)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SelectionIcons(selection: configuration.blockList)
                            Text(configuration.blockList.summary)
                                .font(.geist(size: 13))
                                .foregroundStyle(OnboardingStyle.muted)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#9AA3AE"))
                }
                .padding(16)
                .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            Text(configuration.blockList.applicationTokens.count > BlockingService.maximumShieldedApps
                 ? "iOS can block up to \(BlockingService.maximumShieldedApps) individual apps. Choose whole categories to block more."
                 : "Focus blocks and schedules block these.")
                .font(.geist(size: 12))
                .foregroundStyle(OnboardingStyle.muted)
        }
    }

    private func openListPicker() {
        draftList = configuration.blockList
        showsListPicker = true
    }

    // MARK: - Schedules

    private var schedulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Schedules",
                          action: configuration.schedules.count < BlockingConfiguration.maximumSchedules
                            ? ("Add", { editingSchedule = ScheduleDraft(schedule: BlockSchedule.presets[0].duplicated(), isNew: true) })
                            : nil)
            if configuration.schedules.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Blocks that turn on by themselves. Start with one of these:")
                        .font(.geist(size: 14))
                        .foregroundStyle(OnboardingStyle.muted)
                    ForEach(BlockSchedule.presets) { preset in
                        Button {
                            editingSchedule = ScheduleDraft(schedule: preset.duplicated(), isNew: true)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name).font(.geist(size: 15, weight: .semibold))
                                    Text(Self.describe(preset)).font(.geist(size: 13)).foregroundStyle(OnboardingStyle.muted)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(OnboardingStyle.navy)
                            }
                            .foregroundStyle(OnboardingStyle.navy)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(spacing: 8) {
                        ForEach(configuration.schedules) { schedule in
                            scheduleRow(schedule, now: context.date)
                        }
                    }
                }
            }
        }
    }

    private func scheduleRow(_ schedule: BlockSchedule, now: Date) -> some View {
        let isOn = schedule.isEnabled && schedule.isActive(at: now)
        return HStack(spacing: 12) {
            Button { editingSchedule = ScheduleDraft(schedule: schedule, isNew: false) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(schedule.name)
                            .font(.geist(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.navy)
                        if isOn { StatusBadge(text: "On now") }
                    }
                    Text(Self.describe(schedule))
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle(schedule.name, isOn: Binding(
                get: { schedule.isEnabled },
                set: { blocking.setEnabled($0, schedule: schedule) }
            ))
            .labelsHidden()
            .tint(Color(hex: "#2BB673"))
            .disabled(!blocking.canTurnOff(schedule, at: now))
        }
        .padding(16)
        .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Limits

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Daily limits",
                          action: configuration.limits.count < BlockingConfiguration.maximumLimits
                            ? ("Add", { editingLimit = LimitDraft(limit: AppLimit(), isNew: true) })
                            : nil)
            if configuration.limits.isEmpty {
                Button { editingLimit = LimitDraft(limit: AppLimit(), isNew: true) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(OnboardingStyle.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add a daily limit")
                                .font(.geist(size: 15, weight: .semibold))
                                .foregroundStyle(OnboardingStyle.navy)
                            Text("Give an app a daily allowance. When it’s used up, the app is blocked until midnight.")
                                .font(.geist(size: 13))
                                .foregroundStyle(OnboardingStyle.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                ForEach(configuration.limits) { limit in
                    HStack(spacing: 12) {
                        Button { editingLimit = LimitDraft(limit: limit, isNew: false) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                SelectionIcons(selection: limit.selection, size: 24)
                                Text("\(Self.format(minutes: limit.dailyMinutes)) a day · \(limit.selection.summary)")
                                    .font(.geist(size: 13))
                                    .foregroundStyle(OnboardingStyle.muted)
                                if let pending = limit.pending {
                                    Label(Self.describe(pending), systemImage: "clock.arrow.circlepath")
                                        .font(.geist(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hex: "#235187"))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Toggle("Daily limit", isOn: Binding(
                            get: { limit.isEnabled },
                            set: { blocking.setEnabled($0, limit: limit) }
                        ))
                        .labelsHidden()
                        .tint(Color(hex: "#2BB673"))
                    }
                    .padding(16)
                    .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    // MARK: - Strict mode

    private var strictModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { configuration.isStrict() },
                set: { blocking.setStrictMode($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Strict mode", systemImage: "lock.shield")
                        .font(.geist(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingStyle.navy)
                    Text("Focus blocks can’t end early, running schedules can’t be turned off, and loosening a daily limit waits until tomorrow.")
                        .font(.geist(size: 13))
                        .foregroundStyle(OnboardingStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Color(hex: "#2BB673"))
            .disabled(configuration.isStrict() && (!blocking.canDisableStrictMode || blocking.strictModeEndsAt != nil))
            .padding(16)
            .background(OnboardingStyle.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if blocking.strictModeEndsAt != nil {
                HStack(spacing: 8) {
                    Text("Strict mode turns off at midnight.")
                        .font(.geist(size: 12))
                        .foregroundStyle(OnboardingStyle.muted)
                    Spacer(minLength: 0)
                    Button("Keep it on") { blocking.setStrictMode(true) }
                        .font(.geist(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0063D6"))
                }
            } else if configuration.isStrict() && !blocking.canDisableStrictMode {
                Text("You can turn strict mode off when nothing is blocking.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
            } else if configuration.isStrict() && configuration.limits.contains(where: \.isEnabled) {
                Text("With daily limits on, turning strict mode off takes effect at midnight.")
                    .font(.geist(size: 12))
                    .foregroundStyle(OnboardingStyle.muted)
            }
        }
    }

    // MARK: - Formatting

    static func format(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    static func time(_ minuteOfDay: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minuteOfDay / 60, minute: minuteOfDay % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "From tomorrow: 1h a day", "Turns off at midnight", "Removed at midnight".
    static func describe(_ pending: AppLimit.PendingChange) -> String {
        if pending.removes { return "Removed at midnight" }
        if !pending.isEnabled { return "Turns off at midnight" }
        return "From tomorrow: \(format(minutes: pending.dailyMinutes)) a day · \(pending.selection.summary)"
    }

    static func describe(_ schedule: BlockSchedule) -> String {
        "\(time(schedule.startMinute)) – \(time(schedule.endMinute)) · \(schedule.weekdaySummary())"
    }
}

// MARK: - Components

private struct SectionHeader: View {
    let title: String
    var action: (String, () -> Void)?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.geist(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(OnboardingStyle.muted)
            Spacer()
            if let action {
                Button(action.0, action: action.1)
                    .font(.geist(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#0063D6"))
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct StatusBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.geist(size: 11, weight: .bold))
            .foregroundStyle(Color(hex: "#1E8A55"))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color(hex: "#E3F5EB"), in: Capsule())
    }
}

/// App, category, and site icons from Screen Time tokens. iOS draws them;
/// ScreenSpan never learns which apps they are.
struct SelectionIcons: View {
    let selection: FamilyActivitySelection
    var size: CGFloat = 30
    var limit = 7

    var body: some View {
        let apps = Array(selection.applicationTokens)
        let categories = Array(selection.categoryTokens)
        let sites = Array(selection.webDomainTokens)
        let total = apps.count + categories.count + sites.count
        let shownApps = apps.prefix(limit)
        let shownCategories = categories.prefix(max(limit - shownApps.count, 0))
        let shownSites = sites.prefix(max(limit - shownApps.count - shownCategories.count, 0))
        HStack(spacing: 6) {
            ForEach(Array(shownApps), id: \.self) { icon(Label($0)) }
            ForEach(Array(shownCategories), id: \.self) { icon(Label($0)) }
            ForEach(Array(shownSites), id: \.self) { icon(Label($0)) }
            let hidden = total - shownApps.count - shownCategories.count - shownSites.count
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.geist(size: 12, weight: .semibold))
                    .foregroundStyle(OnboardingStyle.muted)
                    .frame(width: size, height: size)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selection.summary)
    }

    private func icon(_ label: some View) -> some View {
        label
            .labelStyle(.iconOnly)
            .font(.system(size: size * 0.8))
            .frame(width: size, height: size)
    }
}
