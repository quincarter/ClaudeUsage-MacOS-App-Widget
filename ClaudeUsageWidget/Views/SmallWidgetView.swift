import ClaudeUsageShared
import SwiftUI
import WidgetKit

public struct SmallWidgetView: View {
    public let entry: ClaudeUsageEntry

    public init(entry: ClaudeUsageEntry) {
        self.entry = entry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Status badge & icon
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)
                        .frame(width: 7, height: 7)

                    Text(entry.status.statusTitle)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(entry.status.isPeak ? Color.peakRed : Color.offPeakGreen)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    (entry.status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.15)
                )
                .cornerRadius(4)

                Spacer()

                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .cornerRadius(3)
            }

            // Countdown / Subtitle
            VStack(alignment: .leading, spacing: 2) {
                countdownMainView
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(countdownSubText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            // Primary Account info
            if let primary = entry.primaryAccount {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: primary.colorHex))
                            .frame(width: 6, height: 6)
                        Text(primary.name)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    // Progress & Metric
                    HStack {
                        switch primary.type {
                        case .rollingTracker:
                            let remaining = primary.snapshot.remainingMessages(at: entry.date)
                            Text("\(remaining) left")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(primary.snapshot.activeCount(at: entry.date))/\(primary.snapshot.rollingLimit)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        case .anthropicAPI:
                            Text(primary.snapshot.formattedCost)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                            Spacer()
                            Text(primary.snapshot.formattedTokens)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        case .claudeWeb:
                            if primary.snapshot.isFiveHourExhausted {
                                Text("0 left (100%)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.peakRed)
                                Spacer()
                                if let cd = primary.snapshot.fiveHourResetFormatted(at: entry.date, compact: true) {
                                    Text(cd)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.peakRed)
                                }
                            } else if let wk = primary.snapshot.weeklyPercent, wk >= 95.0 {
                                Text("\(Int(wk))% Weekly")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.peakRed)
                                Spacer()
                                if let wkReset = primary.snapshot.weeklyResetFormatted(at: entry.date, compact: true) {
                                    Text(wkReset)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.peakRed)
                                }
                            } else if let fh = primary.snapshot.fiveHourPercent {
                                Text("\(Int(fh))% 5h")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(fh >= 80 ? .claudeBrand : .primary)
                                Spacer()
                                if let wk = primary.snapshot.weeklyPercent {
                                    Text("Wk: \(Int(wk))%")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text(primary.tierDescription)
                                    .font(.system(size: 10, weight: .semibold))
                                Spacer()
                            }
                        }
                    }

                    // Progress Capsule
                    GeometryReader { geo in
                        let fraction = primary.snapshot.usageFraction(at: entry.date)
                        let barColor: Color = {
                            if primary.type == .claudeWeb && (primary.snapshot.isFiveHourExhausted || (primary.snapshot.weeklyPercent ?? 0) >= 95.0) {
                                return Color.peakRed
                            } else if fraction >= 0.8 {
                                return Color.claudeBrand
                            }
                            return Color(hex: primary.colorHex)
                        }()

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.18))
                                .frame(height: 3)
                            Capsule()
                                .fill(barColor)
                                .frame(width: max(3, geo.size.width * CGFloat(fraction)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(5)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            } else {
                Text("No accounts added")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .containerBackground(for: .widget) {
            Color(nsColor: .windowBackgroundColor)
        }
    }

    @ViewBuilder
    private var countdownMainView: some View {
        switch entry.status {
        case .peakActive(let endsAt, _):
            Text("Ends in ") + Text(endsAt, style: .relative)
        case .approachingPeak(let startsAt, _):
            Text("In ") + Text(startsAt, style: .relative)
        case .offPeak(let nextDate, let until):
            if until > 24 * 3600 {
                Text(formatOffPeakDate(nextDate))
            } else {
                Text("Peak in ") + Text(nextDate, style: .relative)
            }
        }
    }

    private func formatOffPeakDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }

    private var countdownSubText: String {
        switch entry.status {
        case .peakActive:
            return "\(entry.slice.localStartString) – \(entry.slice.localEndString)"
        case .approachingPeak:
            return "Session limits drain faster"
        case .offPeak:
            return entry.slice.hasPeakToday ? "Standard rate limits active" : "Weekend (All Off-Peak)"
        }
    }
}
