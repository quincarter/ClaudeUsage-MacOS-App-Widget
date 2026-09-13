import Foundation
import UserNotifications

public final class NotificationManager: Sendable {
    public static let shared = NotificationManager()

    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Schedules recurring notifications for peak window start & end
    public func schedulePeakNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["claude.peak.start", "claude.peak.end"])

        // Mon-Fri 5:00 AM PT
        // Convert to Pacific Time components
        let engine = PeakTimeEngine.shared

        // We can schedule for each weekday 2...6
        for weekday in 2...6 {
            // Start Notification
            let startContent = UNMutableNotificationContent()
            startContent.title = "⚡ Claude Peak Hours Begun"
            startContent.body = "High traffic window active (5:00 AM – 11:00 AM PT). Stricter rate limits and slower generations may occur."
            startContent.sound = .default

            var startComponents = DateComponents()
            startComponents.timeZone = engine.pacificTimeZone
            startComponents.weekday = weekday
            startComponents.hour = 5
            startComponents.minute = 0

            let startTrigger = UNCalendarNotificationTrigger(dateMatching: startComponents, repeats: true)
            let startRequest = UNNotificationRequest(identifier: "claude.peak.start.\(weekday)", content: startContent, trigger: startTrigger)
            center.add(startRequest)

            // End Notification
            let endContent = UNMutableNotificationContent()
            endContent.title = "🟢 Claude Peak Hours Ended"
            endContent.body = "Claude is now in Off-Peak hours. Optimal performance and standard limits restored."
            endContent.sound = .default

            var endComponents = DateComponents()
            endComponents.timeZone = engine.pacificTimeZone
            endComponents.weekday = weekday
            endComponents.hour = 11
            endComponents.minute = 0

            let endTrigger = UNCalendarNotificationTrigger(dateMatching: endComponents, repeats: true)
            let endRequest = UNNotificationRequest(identifier: "claude.peak.end.\(weekday)", content: endContent, trigger: endTrigger)
            center.add(endRequest)
        }
    }
}
