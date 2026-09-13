import ClaudeUsageShared
import WidgetKit
import SwiftUI

public struct ClaudeUsageEntry: TimelineEntry {
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

public struct ClaudeUsageTimelineProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> ClaudeUsageEntry {
        let now = Date()
        let engine = PeakTimeEngine.shared
        let store = AccountStore.shared
        store.loadAccounts()
        let accounts = store.accounts.isEmpty ? ClaudeAccount.sampleAccounts : store.accounts
        return ClaudeUsageEntry(
            date: now,
            status: engine.currentStatus(at: now),
            slice: engine.dayTimelineSlice(for: now),
            accounts: accounts,
            primaryAccount: accounts.first
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (ClaudeUsageEntry) -> Void) {
        let now = Date()
        let engine = PeakTimeEngine.shared
        let store = AccountStore.shared
        store.loadAccounts()
        let status = engine.currentStatus(at: now)
        let slice = engine.dayTimelineSlice(for: now)

        let entry = ClaudeUsageEntry(
            date: now,
            status: status,
            slice: slice,
            accounts: store.accounts,
            primaryAccount: store.primaryAccount
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeUsageEntry>) -> Void) {
        let now = Date()
        let engine = PeakTimeEngine.shared
        let store = AccountStore.shared
        store.loadAccounts()
        let accounts = store.accounts
        let primary = store.primaryAccount

        var entries: [ClaudeUsageEntry] = []

        // Current entry
        let currentStatus = engine.currentStatus(at: now)
        let currentSlice = engine.dayTimelineSlice(for: now)
        entries.append(ClaudeUsageEntry(
            date: now,
            status: currentStatus,
            slice: currentSlice,
            accounts: accounts,
            primaryAccount: primary
        ))

        // Intermediate entries every 15 minutes for 1 hour to keep timeline & countdown updated
        for offsetMinutes in [15, 30, 45, 60] {
            let futureDate = now.addingTimeInterval(Double(offsetMinutes) * 60)
            let status = engine.currentStatus(at: futureDate)
            let slice = engine.dayTimelineSlice(for: futureDate)
            entries.append(ClaudeUsageEntry(
                date: futureDate,
                status: status,
                slice: slice,
                accounts: accounts,
                primaryAccount: primary
            ))
        }

        // Target next refresh in 15 minutes
        let nextRefresh = now.addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }
}

public struct ClaudeUsageWidget: Widget {
    public let kind: String = "ClaudeUsageWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeUsageTimelineProvider()) { entry in
            ClaudeUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage & Peak Tracker")
        .description("Track Claude weekday peak usage windows and monitor usage across your accounts.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

public struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    public let entry: ClaudeUsageEntry

    public init(entry: ClaudeUsageEntry) {
        self.entry = entry
    }

    public var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
