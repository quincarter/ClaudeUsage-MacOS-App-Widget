import Foundation

public final class PeakTimeEngine: Sendable {
    public static let shared = PeakTimeEngine()

    /// Canonical calendar is UTC (1:00 PM – 7:00 PM UTC on weekdays)
    public let utcCalendar: Calendar
    public let utcTimeZone: TimeZone

    /// Backwards compatibility properties
    public let ptCalendar: Calendar
    public let pacificTimeZone: TimeZone

    public init() {
        var uCal = Calendar(identifier: .gregorian)
        guard let uZone = TimeZone(identifier: "UTC") else {
            fatalError("UTC timezone not found")
        }
        uCal.timeZone = uZone
        self.utcCalendar = uCal
        self.utcTimeZone = uZone

        var pCal = Calendar(identifier: .gregorian)
        let pZone = TimeZone(identifier: "America/Los_Angeles") ?? uZone
        pCal.timeZone = pZone
        self.ptCalendar = pCal
        self.pacificTimeZone = pZone
    }

    /// Determines if a specific date falls in the Claude peak window (Weekdays 1:00 PM - 7:00 PM UTC / 13:00 - 19:00 UTC)
    public func isPeak(at date: Date = Date()) -> Bool {
        let weekday = utcCalendar.component(.weekday, from: date)
        // 1 = Sunday, 2 = Monday, ..., 6 = Friday, 7 = Saturday
        guard weekday >= 2 && weekday <= 6 else {
            return false // Weekends are never peak
        }

        let hour = utcCalendar.component(.hour, from: date)
        let minute = utcCalendar.component(.minute, from: date)
        let second = utcCalendar.component(.second, from: date)
        let totalSecondsInDay = hour * 3600 + minute * 60 + second

        let peakStartSeconds = 13 * 3600       // 13:00:00 UTC (1:00 PM UTC)
        let peakEndSeconds = 19 * 3600        // 19:00:00 UTC (7:00 PM UTC)

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

    /// Returns the end date of the current peak window (19:00:00 UTC)
    public func endOfCurrentPeak(from date: Date) -> Date {
        var components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 19
        components.minute = 0
        components.second = 0
        return utcCalendar.date(from: components) ?? date.addingTimeInterval(3600)
    }

    /// Finds the exact start date and time of the upcoming peak window (13:00:00 UTC on next weekday)
    public func nextPeakStartDate(from date: Date) -> Date {
        var checkDate = date
        for _ in 0..<8 {
            let weekday = utcCalendar.component(.weekday, from: checkDate)
            let isWeekday = (weekday >= 2 && weekday <= 6)

            if isWeekday {
                var candidateComponents = utcCalendar.dateComponents([.year, .month, .day], from: checkDate)
                candidateComponents.hour = 13
                candidateComponents.minute = 0
                candidateComponents.second = 0

                if let candidateDate = utcCalendar.date(from: candidateComponents) {
                    if candidateDate > date {
                        return candidateDate
                    }
                }
            }

            // Advance to next day at 00:01 UTC
            guard let nextDay = utcCalendar.date(byAdding: .day, value: 1, to: checkDate) else {
                break
            }
            var nextComponents = utcCalendar.dateComponents([.year, .month, .day], from: nextDay)
            nextComponents.hour = 0
            nextComponents.minute = 1
            nextComponents.second = 0
            checkDate = utcCalendar.date(from: nextComponents) ?? nextDay
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
        let localEndOfDay = localCal.date(byAdding: .day, value: 1, to: localStartOfDay) ?? localStartOfDay.addingTimeInterval(86400)
        let secondsInDay: Double = max(1.0, localEndOfDay.timeIntervalSince(localStartOfDay))

        let currentSeconds = date.timeIntervalSince(localStartOfDay)
        let currentFraction = min(1.0, max(0.0, currentSeconds / secondsInDay))

        // Check UTC peak windows that intersect or correspond to this local day (-1, 0, +1 days relative to date)
        var matchingWindow: (start: Date, end: Date)?
        for dayOffset in -1...1 {
            guard let checkDate = localCal.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = utcCalendar.component(.weekday, from: checkDate)
            guard weekday >= 2 && weekday <= 6 else { continue }

            var comp = utcCalendar.dateComponents([.year, .month, .day], from: checkDate)
            comp.hour = 13
            comp.minute = 0
            comp.second = 0
            guard let pStart = utcCalendar.date(from: comp) else { continue }
            comp.hour = 19
            guard let pEnd = utcCalendar.date(from: comp) else { continue }

            // Check if window overlaps with local day [localStartOfDay, localEndOfDay]
            if pEnd > localStartOfDay && pStart < localEndOfDay {
                matchingWindow = (pStart, pEnd)
                break
            }
        }

        // If not directly overlapping on this local day (e.g. weekend), find nearest weekday window for reference labels
        let peakWindow = matchingWindow ?? {
            var comp = utcCalendar.dateComponents([.year, .month, .day], from: date)
            comp.hour = 13
            comp.minute = 0
            comp.second = 0
            let s = utcCalendar.date(from: comp) ?? date
            comp.hour = 19
            let e = utcCalendar.date(from: comp) ?? date
            return (s, e)
        }()

        let hasPeakToday = (matchingWindow != nil)

        let peakStartSecondsInLocal = peakWindow.start.timeIntervalSince(localStartOfDay)
        let peakEndSecondsInLocal = peakWindow.end.timeIntervalSince(localStartOfDay)

        let startFraction = min(1.0, max(0.0, peakStartSecondsInLocal / secondsInDay))
        let endFraction = min(1.0, max(0.0, peakEndSecondsInLocal / secondsInDay))

        let localFormatter = DateFormatter()
        localFormatter.timeZone = targetTimezone
        localFormatter.dateFormat = "h:mm a"

        let startStr = localFormatter.string(from: peakWindow.start)
        let endStr = localFormatter.string(from: peakWindow.end)

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
        let regions: [(code: String, name: String, tzId: String)] = [
            ("UTC", "Coordinated Universal Time", "UTC"),
            ("ET", "Eastern Time", "America/New_York"),
            ("PT", "Pacific Time", "America/Los_Angeles"),
            ("CET", "Central European Time", "Europe/Paris")
        ]

        var results: [TimezonePeakWindow] = []

        for region in regions {
            guard let tz = TimeZone(identifier: region.tzId) else { continue }
            let isCurrent = (tz.identifier == deviceTimezone.identifier)

            let timeStr = DateFormatting.formatTimeOnly(date, in: tz)
            let slice = dayTimelineSlice(for: date, targetTimezone: tz)
            let windowString = "\(slice.localStartString) – \(slice.localEndString)"

            results.append(TimezonePeakWindow(
                regionCode: region.code,
                regionName: region.name,
                timezone: tz,
                localTimeFormatted: timeStr,
                windowString: windowString,
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
