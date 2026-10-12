import UserNotifications

enum NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { scheduleWeekendReminders() }
        }
    }

    static func scheduleWeekendReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekend_saturday", "weekend_sunday"])

        let content = UNMutableNotificationContent()
        content.title = "今日は競馬開催日！"
        content.body = "今日のレース、予想はもう決まった？🏇"
        content.sound = .default

        for (id, weekday) in [("weekend_saturday", 7), ("weekend_sunday", 1)] {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = 8
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
