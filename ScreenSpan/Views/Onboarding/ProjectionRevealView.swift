import DeviceActivity
import SwiftUI

struct ProjectionRevealView: View {
    var viewModel: OnboardingViewModel

    @AppStorage(SharedConstants.UserDefaultsKey.onboardingAnalysisCompleted.rawValue, store: .appGroup)
    private var onboardingAnalysisCompleted = false

    @StateObject private var completionObserver = DarwinNotificationObserver(
        name: SharedConstants.onboardingAnalysisCompletedNotification
    )

    @State private var isPreparing = false

    private let titleColor = Color(hex: "#051425")
    private let subtitleColor = Color(hex: "#595959")
    private let accentColor = Color(hex: "#C82020")

    var body: some View {
        ZStack {
            analysisLoadingView

            GeometryReader { proxy in
                DeviceActivityReport(
                    .onboardingAnalysis,
                    filter: .screenSpanProjectionAverage
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: proxy.size.height,
                    alignment: .top
                )
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            onboardingAnalysisCompleted = false
            UserDefaults.appGroup.set(false, forKey: SharedConstants.UserDefaultsKey.onboardingAnalysisCompleted.rawValue)
            UserDefaults.appGroup.synchronize()
            isPreparing = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingAnalysisCompleted)) { _ in
            completeAnalysisIfNeeded()
        }
        .onChange(of: onboardingAnalysisCompleted) { _, completed in
            guard completed else { return }
            completeAnalysisIfNeeded()
        }
    }

    private var analysisLoadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "#F0DADA"), lineWidth: 8)
                    .frame(width: 86, height: 86)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 86, height: 86)
                    .rotationEffect(.degrees(isPreparing ? 360 : 0))
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: isPreparing)

                Image(systemName: "hourglass")
                    .font(.geist(size: 24, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            VStack(spacing: 10) {
                Text("Preparing your life map")
                    .font(.geist(size: 28, weight: .bold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)

                Text("We're asking iOS for your private Screen Time report and building the next few screens inside the secure report view.")
                    .font(.geist(size: 16, weight: .medium))
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 28)

            Spacer()

            Text("Your usage data stays inside Apple's Screen Time report extension.")
                .font(.geist(size: 13, weight: .medium))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 34)
        }
    }

    private func completeAnalysisIfNeeded() {
        guard viewModel.currentStep == .lifeGridReveal else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.currentStep = .paywall
        }
    }
}

extension Notification.Name {
    static let onboardingAnalysisCompleted = Notification.Name(SharedConstants.onboardingAnalysisCompletedNotification)
}

private final class DarwinNotificationObserver: ObservableObject {
    private let notificationName: String

    init(name: String) {
        self.notificationName = name

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<DarwinNotificationObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                instance.postLocalNotification()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(notificationName as CFString),
            nil
        )
    }

    private func postLocalNotification() {
        DispatchQueue.main.async { [notificationName] in
            NotificationCenter.default.post(
                name: Notification.Name(notificationName),
                object: nil
            )
        }
    }
}
