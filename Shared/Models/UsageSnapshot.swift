import Foundation

public struct UsageSnapshot: Codable, Equatable, Sendable {
    // API Tokens
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalCostUSD: Double

    // Rate limits (from API response headers)
    public var requestsRemaining: Int?
    public var requestsLimit: Int?
    public var tokensRemaining: Int?
    public var tokensLimit: Int?

    // Claude.ai Web or Local Rolling Window
    public var recentInvocations: [Date]
    public var rollingLimit: Int
    public var rollingWindowSeconds: TimeInterval

    // Claude.ai Web Specific Limits
    public var fiveHourPercent: Double?
    public var fiveHourResetsAt: Date?
    public var weeklyPercent: Double?
    public var weeklyResetsAt: Date?
    public var extraUsagePercent: Double?
    public var activeLimitKind: String?
    public var sevenDayBreakdown: [String: Double]?

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalCostUSD: Double = 0.0,
        requestsRemaining: Int? = nil,
        requestsLimit: Int? = nil,
        tokensRemaining: Int? = nil,
        tokensLimit: Int? = nil,
        recentInvocations: [Date] = [],
        rollingLimit: Int = 45,
        rollingWindowSeconds: TimeInterval = 5 * 3600,
        fiveHourPercent: Double? = nil,
        fiveHourResetsAt: Date? = nil,
        weeklyPercent: Double? = nil,
        weeklyResetsAt: Date? = nil,
        extraUsagePercent: Double? = nil,
        activeLimitKind: String? = nil,
        sevenDayBreakdown: [String: Double]? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCostUSD = totalCostUSD
        self.requestsRemaining = requestsRemaining
        self.requestsLimit = requestsLimit
        self.tokensRemaining = tokensRemaining
        self.tokensLimit = tokensLimit
        self.recentInvocations = recentInvocations
        self.rollingLimit = rollingLimit
        self.rollingWindowSeconds = rollingWindowSeconds
        self.fiveHourPercent = fiveHourPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.weeklyPercent = weeklyPercent
        self.weeklyResetsAt = weeklyResetsAt
        self.extraUsagePercent = extraUsagePercent
        self.activeLimitKind = activeLimitKind
        self.sevenDayBreakdown = sevenDayBreakdown
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    /// Computes active invocations within the rolling window
    public func activeInvocations(at referenceDate: Date = Date()) -> [Date] {
        let cutoff = referenceDate.addingTimeInterval(-rollingWindowSeconds)
        return recentInvocations.filter { $0 > cutoff }
    }

    public func activeCount(at referenceDate: Date = Date()) -> Int {
        activeInvocations(at: referenceDate).count
    }

    public func remainingMessages(at referenceDate: Date = Date()) -> Int {
        max(0, rollingLimit - activeCount(at: referenceDate))
    }

    public var hasWebUsageData: Bool {
        fiveHourPercent != nil || weeklyPercent != nil
    }

    public var isFiveHourExhausted: Bool {
        guard let p = fiveHourPercent else { return false }
        return p >= 100.0
    }

    public var isWeeklyExhausted: Bool {
        guard let p = weeklyPercent else { return false }
        return p >= 100.0
    }

    public func usageFraction(at referenceDate: Date = Date()) -> Double {
        if hasWebUsageData {
            if isFiveHourExhausted { return 1.0 }
            if isWeeklyExhausted { return 1.0 }
            if let fh = fiveHourPercent, fh > 0 {
                return min(1.0, fh / 100.0)
            }
            if let wk = weeklyPercent {
                return min(1.0, wk / 100.0)
            }
            return 0.0
        }

        guard rollingLimit > 0 else { return 0.0 }
        let count = Double(activeCount(at: referenceDate))
        return min(1.0, count / Double(rollingLimit))
    }

    public func fiveHourResetCountdown(at referenceDate: Date = Date()) -> String? {
        guard let reset = fiveHourResetsAt else { return nil }
        let remaining = reset.timeIntervalSince(referenceDate)
        if remaining <= 0 { return "Resetting now" }
        return "Resets in \(DateFormatting.formatDuration(remaining))"
    }

    public func weeklyResetCountdown(at referenceDate: Date = Date()) -> String? {
        guard let reset = weeklyResetsAt else { return nil }
        let remaining = reset.timeIntervalSince(referenceDate)
        if remaining <= 0 { return "Resets now" }
        if remaining > 24 * 3600 {
            let days = Int(remaining / (24 * 3600))
            let hours = Int((remaining.truncatingRemainder(dividingBy: 24 * 3600)) / 3600)
            return "\(days)d \(hours)h left"
        }
        return DateFormatting.formatDuration(remaining)
    }

    public func fiveHourResetFormatted(at referenceDate: Date = Date(), compact: Bool = false) -> String? {
        guard let reset = fiveHourResetsAt else { return nil }
        let remaining = reset.timeIntervalSince(referenceDate)
        if remaining <= 0 { return "Resetting now" }
        return DateFormatting.formatResetTime(reset, relativeTo: referenceDate, compact: compact)
    }

    public func weeklyResetFormatted(at referenceDate: Date = Date(), compact: Bool = false) -> String? {
        guard let reset = weeklyResetsAt else { return nil }
        let remaining = reset.timeIntervalSince(referenceDate)
        if remaining <= 0 { return "Resets now" }
        return DateFormatting.formatWeeklyReset(reset, relativeTo: referenceDate, compact: compact)
    }

    public func nextSlotFreeDate(at referenceDate: Date = Date()) -> Date? {
        if let fiveHourReset = fiveHourResetsAt, fiveHourReset > referenceDate {
            return fiveHourReset
        }
        let active = activeInvocations(at: referenceDate).sorted()
        guard let oldest = active.first else { return nil }
        return oldest.addingTimeInterval(rollingWindowSeconds)
    }

    public var formattedCost: String {
        String(format: "$%.2f", totalCostUSD)
    }

    public var formattedTokens: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000.0)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000.0)
        } else {
            return "\(total)"
        }
    }
}
