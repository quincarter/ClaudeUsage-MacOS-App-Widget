import Foundation

public final class PeakTimeEngine: Sendable {
    public static let shared = PeakTimeEngine()

    /// Pacific Time calendar is the canonical reference
    public let ptCalendar: Calendar
    public let pacificTimeZone: TimeZone

    public init() {
        var cal = Calendar(identifier: .gregorian)
        guard let ptZone = TimeZone(identifier: "America/Los_Angeles") else {
            fatalError("America/Los_Angeles timezone not found")
        }
        cal.timeZone = ptZone
        self.ptCalendar = cal
        self.pacificTimeZone = ptZone
    }

    /// Determines if a specific date falls in the Claude peak window (Weekdays 5:00 AM - 11:00 AM PT)
    public func isPeak(at date: Date = Date()) -> Bool {
        let weekday = ptCalendar.component(.weekday, from: date)
        // 1 = Sunday, 2 = Monday, ..., 6 = Friday, 7 = Saturday
        guard weekday >= 2 && weekday <= 6 else {
            return false // Weekends are never peak
        }

        let hour = ptCalendar.component(.hour, from: date)
        let minute = ptCalendar.component(.minute, from: date)
        let second = ptCalendar.component(.second, from: date)
        let totalSecondsInDay = hour * 3600 + minute * 60 + second

        let peakStartSeconds = 5 * 3600       // 05:00:00 AM PT
        let peakEndSeconds = 11 * 3600        // 11:00:00 AM PT

        return totalSecondsInDay >= peakStartSeconds && totalSecondsInDay < peakEndSeconds
    }

    /// Calculates current peak status with countdowns
    public func currentStatus(at date: Date = Date()) -> PeakStatus {
        if isPeak(at: date) {
            let endsAt = endOfCurrentPeak(from: date)
            let remaining = max(0, endsAt.timeIntervalSince(date))
            return .peakActive(endsAt: endsAt, timeRemaining: remaining)
        }

        let nextStartsAt = nextPeakStartDate(from: date)
        let untilNext = max(0, nextStartsAt.timeIntervalSince(date))

        // If within 1 hour of peak start, consider it imminent
        if untilNext <= 3600 {
            return .approachingPeak(startsAt: nextStartsAt, timeRemaining: untilNext)
        }

        return .offPeak(nextStartsAt: nextStartsAt, timeUntilNext: untilNext)
    }

    /// Returns the end date of the current peak window
    public func endOfCurrentPeak(from date: Date) -> Date {
        var components = ptCalendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 11
        components.minute = 0
        components.second = 0
        return ptCalendar.date(from: components) ?? date.addingTimeInterval(3600)
    }

    /// Finds the exact start date and time of the upcoming peak window
    public func nextPeakStartDate(from date: Date) -> Date {
        var checkDate = date
        for _ in 0..<8 {
            let weekday = ptCalendar.component(.weekday, from: checkDate)
            let isWeekday = (weekday >= 2 && weekday <= 6)

            if isWeekday {
                var candidateComponents = ptCalendar.dateComponents([.year, .month, .day], from: checkDate)
                candidateComponents.hour = 5
                candidateComponents.minute = 0
                candidateComponents.second = 0

                if let candidateDate = ptCalendar.date(from: candidateComponents) {
                    if candidateDate > date {
                        return candidateDate
                    }
                }
            }

            // Advance to next day at 00:01 PT
            guard let nextDay = ptCalendar.date(byAdding: .day, value: 1, to: checkDate) else {
                break
            }
            var nextComponents = ptCalendar.dateComponents([.year, .month, .day], from: nextDay)
            nextComponents.hour = 0
            nextComponents.minute = 1
            nextComponents.second = 0
            checkDate = ptCalendar.date(from: nextComponents) ?? nextDay
        }

        // Fallback: 24h later
        return date.addingTimeInterval(24 * 3600)
    }

    /// Computes timeline fractions for visual representation in any target timezone
    public func dayTimelineSlice(
        for date: Date = Date(),
        targetTimezone: TimeZone = .current
    ) -> DayTimelineSlice {
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = targetTimezone

        let localStartOfDay = localCal.startOfDay(for: date)
        let secondsInDay: Double = 86400.0

        let currentSeconds = date.timeIntervalSince(localStartOfDay)
        let currentFraction = min(1.0, max(0.0, currentSeconds / secondsInDay))

        // Determine if today in PT is a weekday
        let ptWeekday = ptCalendar.component(.weekday, from: date)
        let hasPeakToday = (ptWeekday >= 2 && ptWeekday <= 6)

        // Peak start & end in reference to PT today
        var ptComponents = ptCalendar.dateComponents([.year, .month, .day], from: date)
        ptComponents.hour = 5
        ptComponents.minute = 0
        ptComponents.second = 0
        let peakStartToday = ptCalendar.date(from: ptComponents) ?? date

        ptComponents.hour = 11
        let peakEndToday = ptCalendar.date(from: ptComponents) ?? date

        let peakStartSecondsInLocal = peakStartToday.timeIntervalSince(localStartOfDay)
        let peakEndSecondsInLocal = peakEndToday.timeIntervalSince(localStartOfDay)

        let startFraction = min(1.0, max(0.0, peakStartSecondsInLocal / secondsInDay))
        let endFraction = min(1.0, max(0.0, peakEndSecondsInLocal / secondsInDay))

        let localFormatter = DateFormatter()
        localFormatter.timeZone = targetTimezone
        localFormatter.dateFormat = "h:mm a"

        let startStr = localFormatter.string(from: peakStartToday)
        let endStr = localFormatter.string(from: peakEndToday)

        return DayTimelineSlice(
            peakStartFraction: startFraction,
            peakEndFraction: endFraction,
            currentFraction: currentFraction,
            hasPeakToday: hasPeakToday,
            localStartString: startStr,
            localEndString: endStr
        )
    }

    /// Generates reference region cards with peak window translated to their local times
    public func regionalWindows(for date: Date = Date(), deviceTimezone: TimeZone = .current) -> [TimezonePeakWindow] {
        let regions: [(code: String, name: String, tzId: String, window: String)] = [
            ("PT", "Pacific Time", "America/Los_Angeles", "5:00 AM – 11:00 AM"),
            ("ET", "Eastern Time", "America/New_York", "8:00 AM – 2:00 PM"),
            ("GMT", "Greenwich Mean Time (UTC)", "UTC", "1:00 PM – 7:00 PM"),
            ("CET", "Central European Time", "Europe/Paris", "2:00 PM – 8:00 PM")
        ]

        var results: [TimezonePeakWindow] = []

        for region in regions {
            guard let tz = TimeZone(identifier: region.tzId) else { continue }
            let isCurrent = (tz.identifier == deviceTimezone.identifier)

            let timeStr = DateFormatting.formatTimeOnly(date, in: tz)

            results.append(TimezonePeakWindow(
                regionCode: region.code,
                regionName: region.name,
                timezone: tz,
                localTimeFormatted: timeStr,
                windowString: region.window,
                isCurrentDeviceZone: isCurrent
            ))
        }

        // If user's device timezone is not one of the standard four, add it as a primary entry!
        let knownTzIds = Set(regions.map { $0.tzId })
        if !knownTzIds.contains(deviceTimezone.identifier) {
            let slice = dayTimelineSlice(for: date, targetTimezone: deviceTimezone)
            let deviceTimeStr = DateFormatting.formatTimeOnly(date, in: deviceTimezone)
            let deviceWindow = "\(slice.localStartString) – \(slice.localEndString)"

            let customEntry = TimezonePeakWindow(
                regionCode: "LOCAL",
                regionName: "Your Local Time (\(deviceTimezone.abbreviation() ?? "LOCAL"))",
                timezone: deviceTimezone,
                localTimeFormatted: deviceTimeStr,
                windowString: deviceWindow,
                isCurrentDeviceZone: true
            )
            results.insert(customEntry, at: 0)
        }

        return results
    }
}
