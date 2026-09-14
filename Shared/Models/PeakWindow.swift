import Foundation

/// Represents the current peak status of Claude
public enum PeakStatus: Equatable, Sendable {
    case peakActive(endsAt: Date, timeRemaining: TimeInterval)
    case approachingPeak(startsAt: Date, timeRemaining: TimeInterval)
    case offPeak(nextStartsAt: Date, timeUntilNext: TimeInterval)

    public var isPeak: Bool {
        if case .peakActive = self { return true }
        return false
    }

    public var statusTitle: String {
        switch self {
        case .peakActive:
            return "PEAK ACTIVE"
        case .approachingPeak:
            return "PEAK IMMINENT"
        case .offPeak:
            return "OFF-PEAK"
        }
    }

    public var menuBarTitle: String {
        switch self {
        case .peakActive:
            return "PEAK"
        case .approachingPeak:
            return "PEAK SOON"
        case .offPeak:
            return "OFF-PEAK"
        }
    }

    public var statusSubheading: String {
        switch self {
        case .peakActive(_, let remaining):
            return "Ends in \(DateFormatting.formatDuration(remaining))"
        case .approachingPeak(_, let remaining):
            return "Starts in \(DateFormatting.formatDuration(remaining))"
        case .offPeak(let nextDate, let until):
            if until > 24 * 3600 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE 'at' h:mm a"
                return "Next: \(formatter.string(from: nextDate))"
            } else {
                return "Starts in \(DateFormatting.formatDuration(until))"
            }
        }
    }
}

/// Represents key regional timezone representations of the Claude peak window
public struct TimezonePeakWindow: Identifiable, Sendable {
    public var id: String { regionCode }
    public let regionCode: String
    public let regionName: String
    public let timezone: TimeZone
    public let localTimeFormatted: String
    public let windowString: String
    public let isCurrentDeviceZone: Bool

    public init(
        regionCode: String,
        regionName: String,
        timezone: TimeZone,
        localTimeFormatted: String,
        windowString: String,
        isCurrentDeviceZone: Bool = false
    ) {
        self.regionCode = regionCode
        self.regionName = regionName
        self.timezone = timezone
        self.localTimeFormatted = localTimeFormatted
        self.windowString = windowString
        self.isCurrentDeviceZone = isCurrentDeviceZone
    }
}

/// A normalized slice of the 24-hour day used for timeline rendering
public struct DayTimelineSlice: Sendable {
    /// 0.0 (midnight) to 1.0 (midnight next day) in local timezone
    public let peakStartFraction: Double
    /// 0.0 to 1.0 in local timezone
    public let peakEndFraction: Double
    /// Current time position from 0.0 to 1.0
    public let currentFraction: Double
    /// Whether today (local time) has peak hours (false on weekends)
    public let hasPeakToday: Bool
    /// Friendly start hour string (e.g., "8:00 AM")
    public let localStartString: String
    /// Friendly end hour string (e.g., "2:00 PM")
    public let localEndString: String
}
