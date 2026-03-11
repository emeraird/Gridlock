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
        // Remove all old notifications before rescheduling
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        scheduleDailyChallengeReminder()
        scheduleStreakReminder()
        scheduleComebackNudge()
        scheduleDailyRewardReminder()
    }

    // MARK: - Daily Challenge (9 AM)

    static func scheduleDailyChallengeReminder() {
        let messages = [
            ("Daily Challenge Ready!", "Your daily puzzle is waiting. Can you get 3 stars? ⭐"),
            ("New Puzzle!", "Today's challenge just dropped. Show it who's boss! 🧩"),
            ("Daily Brain Workout", "Keep your streak alive with today's puzzle! 🔥"),
            ("Challenge Accepted?", "A new daily puzzle awaits. How fast can you clear it? ⚡"),
        ]

        let message = messages[Int.random(in: 0..<messages.count)]

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
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

    // MARK: - Streak Reminder (8 PM, only if haven't played)

    static func scheduleStreakReminder() {
        guard StreakManager.shared.currentStreak > 0,
              !StreakManager.shared.playedToday else { return }

        let streak = StreakManager.shared.currentStreak

        let content = UNMutableNotificationContent()
        content.title = "Your \(streak)-day streak is at risk! 🔥"
        content.body = "Play a quick game before midnight to keep it alive."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streakReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Comeback Nudge (after 2 days of no play)

    static func scheduleComebackNudge() {
        let messages = [
            ("We miss you! 😢", "Your grid is gathering dust. Come back and clear some lines!"),
            ("It's been a while...", "Your pieces are lonely! Play a quick game? 🧩"),
            ("Remember Gridlock?", "Your high score is waiting to be beaten! 🏆"),
        ]

        let message = messages[Int.random(in: 0..<messages.count)]

        let content = UNMutableNotificationContent()
        content.title = message.0
        content.body = message.1
        content.sound = .default

        // Trigger 48 hours from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)

        let request = UNNotificationRequest(
            identifier: "comebackNudge",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Daily Reward Reminder (10 AM)

    static func scheduleDailyRewardReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Free Reward Waiting! 🎁"
        content.body = "Collect your daily power-up before it expires!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "dailyReward",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    static func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakReminder"])
    }

    static func cancelComebackNudge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["comebackNudge"])
    }

    /// Call when user plays a game — reschedule comeback and cancel streak warning
    static func onGamePlayed() {
        cancelComebackNudge()
        cancelStreakReminder()
        scheduleComebackNudge() // Reset the 48-hour countdown
    }
}
