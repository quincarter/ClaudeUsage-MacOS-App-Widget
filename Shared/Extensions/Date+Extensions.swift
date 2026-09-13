import Foundation

public enum DateFormatting {
    public static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }

    public static func formatTimeOnly(_ date: Date, in timezone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    public static func formatTimeWithSeconds(_ date: Date, in timezone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    /// Formats a reset date into user-friendly text:
    /// - "Resets at 5:30 PM today" (or "5:30 PM today" if compact)
    /// - "Resets at 1:15 AM tomorrow"
    /// - "Resets Mon at 6:00 AM"
    public static func formatResetTime(_ date: Date, relativeTo now: Date = Date(), in timezone: TimeZone = .current, compact: Bool = false) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        // Round seconds to the nearest minute so e.g. 5:29:59 PM displays as 5:30 PM
        let rounded = Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate + 30).rounded(.down))

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = timezone
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: rounded)

        if calendar.isDate(rounded, inSameDayAs: now) {
            return compact ? "\(timeStr) today" : "Resets at \(timeStr) today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(rounded, inSameDayAs: tomorrow) {
            return compact ? "\(timeStr) tomorrow" : "Resets at \(timeStr) tomorrow"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.timeZone = timezone
            dayFormatter.dateFormat = "EEE 'at' h:mm a"
            let dayTimeStr = dayFormatter.string(from: rounded)
            return compact ? dayTimeStr : "Resets \(dayTimeStr)"
        }
    }

    /// Formats weekly reset date:
    /// e.g. "Mon 6:00 AM", "Fri 6:00 AM"
    public static func formatWeeklyReset(_ date: Date, relativeTo now: Date = Date(), in timezone: TimeZone = .current, compact: Bool = false) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let rounded = Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate + 30).rounded(.down))

        let timeFormatter = DateFormatter()
        timeFormatter.timeZone = timezone
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: rounded)

        if calendar.isDate(rounded, inSameDayAs: now) {
            return "\(timeStr) today"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.timeZone = timezone
            dayFormatter.dateFormat = "EEE h:mm a"
            return dayFormatter.string(from: rounded)
        }
    }
}
