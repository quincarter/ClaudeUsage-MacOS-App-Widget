import ClaudeUsageShared
import WidgetKit
import SwiftUI

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

        var timelineDates = Set<Date>()
        timelineDates.insert(now)

        // Add 5-minute intervals for the next 2 hours
        for m in stride(from: 5, through: 120, by: 5) {
            timelineDates.insert(now.addingTimeInterval(Double(m) * 60))
        }

        // Add exact status transition boundaries
        let status = engine.currentStatus(at: now)
        switch status {
        case .peakActive(let endsAt, _):
            if endsAt > now {
                timelineDates.insert(endsAt)
                timelineDates.insert(endsAt.addingTimeInterval(1))
            }
        case .approachingPeak(let startsAt, _):
            if startsAt > now {
                timelineDates.insert(startsAt)
                timelineDates.insert(startsAt.addingTimeInterval(1))
            }
        case .offPeak(let nextStartsAt, _):
            let approachingAt = nextStartsAt.addingTimeInterval(-3600)
            if approachingAt > now && approachingAt < now.addingTimeInterval(2 * 3600) {
                timelineDates.insert(approachingAt)
                timelineDates.insert(approachingAt.addingTimeInterval(1))
            }
            if nextStartsAt > now && nextStartsAt < now.addingTimeInterval(2 * 3600) {
                timelineDates.insert(nextStartsAt)
                timelineDates.insert(nextStartsAt.addingTimeInterval(1))
            }
        }

        // Add upcoming account resets within the 2-hour window
        for account in accounts {
            if let reset = account.snapshot.fiveHourResetsAt, reset > now, reset < now.addingTimeInterval(2 * 3600) {
                timelineDates.insert(reset)
                timelineDates.insert(reset.addingTimeInterval(1))
            }
            if let reset = account.snapshot.weeklyResetsAt, reset > now, reset < now.addingTimeInterval(2 * 3600) {
                timelineDates.insert(reset)
                timelineDates.insert(reset.addingTimeInterval(1))
            }
        }

        let sortedDates = timelineDates.sorted()
        var entries: [ClaudeUsageEntry] = []
        for date in sortedDates {
            let entryStatus = engine.currentStatus(at: date)
            let entrySlice = engine.dayTimelineSlice(for: date)
            entries.append(ClaudeUsageEntry(
                date: date,
                status: entryStatus,
                slice: entrySlice,
                accounts: accounts,
                primaryAccount: primary
            ))
        }

        // Target next refresh: at next status transition or in 15 minutes, whichever is sooner
        var nextRefresh = now.addingTimeInterval(15 * 60)
        switch status {
        case .peakActive(let endsAt, _):
            if endsAt > now && endsAt < nextRefresh {
                nextRefresh = endsAt.addingTimeInterval(1)
            }
        case .approachingPeak(let startsAt, _):
            if startsAt > now && startsAt < nextRefresh {
                nextRefresh = startsAt.addingTimeInterval(1)
            }
        case .offPeak(let nextStartsAt, _):
            let approachingAt = nextStartsAt.addingTimeInterval(-3600)
            if approachingAt > now && approachingAt < nextRefresh {
                nextRefresh = approachingAt.addingTimeInterval(1)
            } else if nextStartsAt > now && nextStartsAt < nextRefresh {
                nextRefresh = nextStartsAt.addingTimeInterval(1)
            }
        }

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
