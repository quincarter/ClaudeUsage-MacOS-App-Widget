import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct ClaudeUsageEntry: @unchecked Sendable {
    public let date: Date
    public let status: PeakStatus
    public let slice: DayTimelineSlice
    public let accounts: [ClaudeAccount]
    public let primaryAccount: ClaudeAccount?

    public init(
        date: Date = Date(),
        status: PeakStatus,
        slice: DayTimelineSlice,
        accounts: [ClaudeAccount] = [],
        primaryAccount: ClaudeAccount? = nil
    ) {
        self.date = date
        self.status = status
        self.slice = slice
        self.accounts = accounts
        self.primaryAccount = primaryAccount
    }
}

#if canImport(WidgetKit)
extension ClaudeUsageEntry: TimelineEntry {}
#endif
