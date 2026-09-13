import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var notifyOnPeakStart: Bool
    public var notifyOnPeakEnd: Bool
    public var targetTimezoneIdentifier: String
    public var refreshIntervalMinutes: Int
    public var showCostInWidget: Bool
    public var showTokensInWidget: Bool

    public init(
        notifyOnPeakStart: Bool = true,
        notifyOnPeakEnd: Bool = true,
        targetTimezoneIdentifier: String = TimeZone.current.identifier,
        refreshIntervalMinutes: Int = 15,
        showCostInWidget: Bool = true,
        showTokensInWidget: Bool = true
    ) {
        self.notifyOnPeakStart = notifyOnPeakStart
        self.notifyOnPeakEnd = notifyOnPeakEnd
        self.targetTimezoneIdentifier = targetTimezoneIdentifier
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.showCostInWidget = showCostInWidget
        self.showTokensInWidget = showTokensInWidget
    }

    public var effectiveTimezone: TimeZone {
        TimeZone(identifier: targetTimezoneIdentifier) ?? .current
    }
}
