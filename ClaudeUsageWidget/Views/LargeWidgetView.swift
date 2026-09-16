import ClaudeUsageShared
import SwiftUI
import WidgetKit

public struct LargeWidgetView: View {
    public let entry: ClaudeUsageEntry

    public init(entry: ClaudeUsageEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)
                            .frame(width: 8, height: 8)

                        Text(entry.status.statusTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)

                        Text("—")
                            .foregroundColor(.secondary)

                        PeakStatusLiveSubheadingView(status: entry.status)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text(entry.status.isPeak ? "⚠️ Reduced message limits & higher response times in effect" : "🟢 Full rate limits and optimal generation speeds")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .cornerRadius(4)
            }
            .padding(8)
            .background((entry.status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.1))
            .cornerRadius(8)

            // Timeline
            PeakTimelineBar(slice: entry.slice, height: 14, showLabels: true)

            Divider()

            // Accounts Section
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CLAUDE ACCOUNTS (\(entry.accounts.count))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                let displayed = Array(entry.accounts.prefix(3))
                if displayed.isEmpty {
                    Text("No accounts configured.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 5) {
                        ForEach(displayed) { account in
                            AccountUsageRow(account: account, referenceDate: entry.date, compact: false)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            // Regional Schedule Reference Bar
            HStack(spacing: 4) {
                regionalPill(code: "UTC", window: "1PM–7PM", isCurrent: TimeZone.current.identifier == "UTC")
                regionalPill(code: "ET", window: regionalWindowString(tzId: "America/New_York"), isCurrent: TimeZone.current.identifier == "America/New_York")
                regionalPill(code: "PT", window: regionalWindowString(tzId: "America/Los_Angeles"), isCurrent: TimeZone.current.identifier == "America/Los_Angeles")
                regionalPill(code: "CET", window: regionalWindowString(tzId: "Europe/Paris"), isCurrent: TimeZone.current.identifier == "Europe/Paris")
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    private func regionalWindowString(tzId: String) -> String {
        guard let tz = TimeZone(identifier: tzId) else { return "" }
        let slice = PeakTimeEngine.shared.dayTimelineSlice(for: entry.date, targetTimezone: tz)
        let start = slice.localStartString.replacingOccurrences(of: ":00", with: "").replacingOccurrences(of: " ", with: "")
        let end = slice.localEndString.replacingOccurrences(of: ":00", with: "").replacingOccurrences(of: " ", with: "")
        return "\(start)–\(end)"
    }

    private func regionalPill(code: String, window: String, isCurrent: Bool) -> some View {
        HStack(spacing: 3) {
            Text(code)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(isCurrent ? .primary : .secondary)
            Text(window)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(isCurrent ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3)
        .background(isCurrent ? Color.claudeBrand.opacity(0.2) : Color.secondary.opacity(0.08))
        .cornerRadius(4)
    }
}
