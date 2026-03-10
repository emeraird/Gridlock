import UIKit
import UserNotifications
import os.log

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.gridlock.app", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        logger.info("Gridlock launched")
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Push Notification Permission

    static func requestNotificationPermissionIfNeeded() {
        let gamesPlayed = UserDefaults.standard.integer(forKey: "totalGamesPlayed")
        guard gamesPlayed >= MonetizationConfig.notificationPermissionPromptAfterGame else { return }
        guard !UserDefaults.standard.bool(forKey: "notificationPermissionRequested") else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "notificationPermissionRequested")
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    NotificationScheduler.scheduleAll()
                }
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Notification Scheduler

enum NotificationScheduler {
    static func scheduleAll() {
        scheduleDailyChallengeReminder()
        scheduleStreakReminder()
    }

    static func scheduleDailyChallengeReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge Ready!"
        content.body = "Your daily puzzle is waiting. Can you get 3 stars?"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "dailyChallenge",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleStreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Don't lose your streak!"
        content.body = "Play a quick game to keep your streak alive."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "streakReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakReminder"])
    }
}
