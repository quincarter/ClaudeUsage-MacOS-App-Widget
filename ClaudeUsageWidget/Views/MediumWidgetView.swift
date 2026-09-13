import ClaudeUsageShared
import SwiftUI
import WidgetKit

public struct MediumWidgetView: View {
    public let entry: ClaudeUsageEntry

    public init(entry: ClaudeUsageEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)
                        .frame(width: 8, height: 8)

                    Text(entry.status.statusTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(entry.status.statusSubheading)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background((entry.status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.12))
                .cornerRadius(5)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(TimeZone.current.abbreviation() ?? "LOCAL")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }

            // Timeline bar
            PeakTimelineBar(slice: entry.slice, height: 12, showLabels: true)

            // Accounts Row (Display up to 2 accounts)
            HStack(spacing: 8) {
                let displayedAccounts = Array(entry.accounts.prefix(2))
                if displayedAccounts.isEmpty {
                    Text("No accounts configured yet. Open Claude Usage to configure.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(displayedAccounts) { account in
                        AccountUsageRow(account: account, referenceDate: entry.date, compact: true)
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }
}
