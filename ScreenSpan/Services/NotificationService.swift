import Foundation
import UIKit
import UserNotifications

/// Service for managing local notifications
@MainActor
class NotificationService: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Request notification authorization
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        } catch {
            print("Failed to request notification authorization: \(error)")
        }
    }

    /// Schedule a daily reminder notification
    func scheduleDailyReminder(at hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time for a check-in"
        content.body = "How much time did you spend on your phone today?"
        content.sound = .default
        content.badge = NSNumber(value: 1)

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: AppConstants.NotificationID.dailyReminder,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            }
        }
    }

    /// Cancel a scheduled notification
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all notifications
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
