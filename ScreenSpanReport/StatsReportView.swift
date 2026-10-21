import SwiftUI
import DeviceActivity
import FamilyControls

/// Stats view rendered inside the `DeviceActivityReport` extension.
///
/// IMPORTANT: This view is the ONLY place allowed to render raw numeric
/// screen-time values. The host app passes no usage data in; it instead
/// embeds this whole view via `DeviceActivityReport(.stats, filter:)`.
///
/// Everything here describes the last seven completed days: the daily
/// average and its lifetime projection to the user-entered planning age,
/// pickups and notifications, and the apps that take the most time. App
/// names and icons are rendered from tokens here and never leave the report.
struct StatsReportView: View {
    let payload: ScreenTimeReportPayload

    @AppStorage(SharedConstants.UserDefaultsKey.currentAge.rawValue, store: .appGroup)
    private var currentAge: Int = 30

    @AppStorage(SharedConstants.UserDefaultsKey.targetAge.rawValue, store: .appGroup)
    private var targetAge: Int = SharedConstants.DefaultValues.targetAge

    private let navy = Color(hex: "#0A1F38")
    private let red = Color(hex: "#F63232")
    private let cardColor = Color(hex: "#F6F7FA")
    private let iconColor = Color(hex: "#235187")

    private var dailyAverageHours: Double { payload.dailyAverageHours ?? 0 }

    private var projection: ProjectionResult {
        projection(forDailyHours: dailyAverageHours)
    }

    var body: some View {
        Group {
            if payload.isAvailable {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        heroYearsSection
                        DonutChartView(
                            phoneTime: projection.dailyPhoneHours,
                            totalWakingHours: SharedConstants.DefaultValues.wakeHoursPerDay
                        )
                        habitTiles
                        if !payload.topApps.isEmpty {
                            topAppsSection
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If this average continues to age \(targetAge). A year means 365 days of 24 hours; the waking-life percentage assumes 8 hours of sleep per day. Pickups count each time you unlock or wake your iPhone.")
                                .font(.geist(size: 12))
                                .foregroundStyle(ScreenSpanAppearance.secondaryText)
                            ReportSourceNote(payload: payload)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
            } else {
                ScreenTimeUnavailableView(
                    title: "We couldn't access your Screen Time data",
                    message: "Stats are only useful with real Screen Time activity, so we aren't showing a fallback number."
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .screenSpanLightSurface()
    }

    // MARK: - Hero

    private var heroYearsSection: some View {
        VStack(spacing: 8) {
            Text("AT YOUR CURRENT PACE")
                .font(.geist(size: 12, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(ScreenSpanAppearance.secondaryText)

            Text(String(format: "%.1f YEARS", projection.yearsOnPhone))
                .font(.geist(size: 40, weight: .heavy))
                .foregroundStyle(navy)
                .multilineTextAlignment(.center)
                .monospacedDigit()

            Text("of your life on your phone by age \(targetAge)")
                .font(.geist(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Habits

    private var habitTiles: some View {
        HStack(spacing: 10) {
            statTile(icon: "clock", value: duration(dailyAverageHours), label: "a day")
            if let pickups = payload.pickupsPerDay {
                statTile(icon: "hand.tap", value: wholeNumber(pickups), label: "pickups a day")
            }
            if let notifications = payload.notificationsPerDay {
                statTile(icon: "bell.badge", value: wholeNumber(notifications), label: "notifications a day")
            }
        }
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.geist(size: 17, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(height: 20)

            Text(value)
                .font(.geist(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#0D141C"))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.geist(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "#595959"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        .background(cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Top apps

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where your time goes")
                    .font(.geist(size: 20, weight: .semibold))
                Text("Your top apps, and what each costs by age \(targetAge) at this pace.")
                    .font(.geist(size: 13))
                    .foregroundStyle(ScreenSpanAppearance.secondaryText)
            }
            VStack(spacing: 0) {
                ForEach(Array(payload.topApps.enumerated()), id: \.element.id) { index, app in
                    if index > 0 { Divider().padding(.leading, 16) }
                    appRow(app)
                }
            }
            .background(cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func appRow(_ app: AppUsage) -> some View {
        let share = dailyAverageHours > 0 ? min(app.dailyHours / dailyAverageHours, 1) : 0
        let years = projection(forDailyHours: app.dailyHours).yearsOnPhone
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                appName(app)
                    .font(.geist(size: 15, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(duration(app.dailyHours)) a day")
                        .font(.geist(size: 15, weight: .semibold))
                        .monospacedDigit()
                    Text(years >= 0.1 ? String(format: "%.1f years", years) : "\(wholeNumber(years * 12)) months")
                        .font(.geist(size: 12, weight: .medium))
                        .foregroundStyle(red)
                        .monospacedDigit()
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#E3E7EE"))
                    Capsule().fill(red.opacity(0.85))
                        .frame(width: max(proxy.size.width * share, 4))
                }
            }
            .frame(height: 5)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
        .accessibilityHint("\(Int((share * 100).rounded())) percent of your daily average")
    }

    private func appName(_ app: AppUsage) -> some View {
        AppNameLabel(app: app)
    }

    // MARK: - Formatting

    private func projection(forDailyHours hours: Double) -> ProjectionResult {
        ProjectionCalculator.calculateProjectionFromDaily(
            currentAge: currentAge,
            targetAge: targetAge,
            dailyHours: hours
        )
    }

    private func duration(_ hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func wholeNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

/// App icon and name from its token, rendered only inside the report.
struct AppNameLabel: View {
    let app: AppUsage

    var body: some View {
        if let token = app.application?.token {
            Label(token)
                .labelStyle(.titleAndIcon)
        } else {
            Text(app.application?.localizedDisplayName ?? app.fallbackName)
        }
    }
}
