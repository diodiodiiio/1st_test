import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private let weeklyID = "photo-review-weekly"

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func scheduleWeeklyReminder(weekday: Int = 1, hour: Int = 21) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyID])

        let content = UNMutableNotificationContent()
        content.title = "今週の写真をレビューしましょう"
        content.body = "先週撮影した写真を整理する時間です"
        content.sound = .default

        var dc = DateComponents()
        dc.weekday = weekday
        dc.hour = hour
        dc.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        center.add(UNNotificationRequest(identifier: weeklyID, content: content, trigger: trigger))
    }

    func cancelWeeklyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyID])
    }

    func updateBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
