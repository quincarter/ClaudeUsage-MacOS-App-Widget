import SwiftUI

public struct AccountUsageRow: View {
    public let account: ClaudeAccount
    public let referenceDate: Date
    public let compact: Bool

    public init(account: ClaudeAccount, referenceDate: Date = Date(), compact: Bool = false) {
        self.account = account
        self.referenceDate = referenceDate
        self.compact = compact
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            // Header Row: Dot, Account Name, Primary Badge, Metric
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: 8, height: 8)

                Text(account.name)
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if account.isPrimary {
                    Text("PRIMARY")
                        .font(.system(size: 7, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.18))
                        .cornerRadius(3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Metric label based on type
                switch account.type {
                case .anthropicAPI:
                    Text(account.snapshot.formattedCost)
                        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)

                case .rollingTracker:
                    Text("\(account.snapshot.activeCount(at: referenceDate))/\(account.snapshot.rollingLimit) msgs")
                        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)

                case .claudeWeb:
                    claudeWebHeaderMetric
                }
            }

            // Progress Bar
            GeometryReader { geo in
                let fraction = progressFraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: compact ? 4 : 5)

                    Capsule()
                        .fill(progressBarColor(fraction: fraction))
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)), height: compact ? 4 : 5)
                }
            }
            .frame(height: compact ? 4 : 5)

            // Details / Secondary limits
            if !compact {
                HStack(alignment: .center) {
                    switch account.type {
                    case .anthropicAPI:
                        Text("\(account.snapshot.formattedTokens) tokens")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let remaining = account.snapshot.requestsRemaining {
                            Text("\(remaining) reqs left")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                    case .rollingTracker:
                        Text("\(account.snapshot.remainingMessages(at: referenceDate)) messages remaining")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        if let freeDate = account.snapshot.nextSlotFreeDate(at: referenceDate) {
                            Text("Next slot: \(DateFormatting.formatTimeOnly(freeDate))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                    case .claudeWeb:
                        claudeWebDetails
                    }
                }
            } else {
                // In compact mode, show subtext if limit reached
                if account.type == .claudeWeb, account.snapshot.isFiveHourExhausted {
                    if let resetText = account.snapshot.fiveHourResetFormatted(at: referenceDate, compact: true) {
                        Text("Resets \(resetText)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.peakRed)
                    }
                }
            }
        }
        .padding(compact ? 4 : 6)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }

    // MARK: - Claude Web Components

    @ViewBuilder
    private var claudeWebHeaderMetric: some View {
        if account.snapshot.isFiveHourExhausted {
            HStack(spacing: 3) {
                Text("100% (5h Limit)")
                    .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded))
                    .foregroundColor(.peakRed)
            }
        } else if let wk = account.snapshot.weeklyPercent, wk >= 95.0 {
            HStack(spacing: 3) {
                Text("\(Int(wk))% Weekly Cap")
                    .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded))
                    .foregroundColor(.peakRed)
            }
        } else if let fh = account.snapshot.fiveHourPercent, fh > 0 {
            HStack(spacing: 3) {
                Text("\(Int(fh))% (5h)")
                    .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                    .foregroundColor(fh >= 80 ? .claudeBrand : .primary)
                if let wk = account.snapshot.weeklyPercent {
                    Text("• \(Int(wk))% Wk")
                        .font(.system(size: compact ? 8 : 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        } else if let wk = account.snapshot.weeklyPercent {
            Text("\(Int(wk))% Weekly")
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .foregroundColor(wk >= 80 ? .claudeBrand : .primary)
        } else {
            Text(account.tierDescription)
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var claudeWebDetails: some View {
        // Left side: 5-Hour Session Window status & reset time
        if account.snapshot.isFiveHourExhausted {
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.peakRed)
                if let resetText = account.snapshot.fiveHourResetFormatted(at: referenceDate) {
                    Text(resetText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.peakRed)
                } else {
                    Text("5h Limit Active")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.peakRed)
                }
            }
        } else if let resetText = account.snapshot.fiveHourResetFormatted(at: referenceDate) {
            Text(resetText)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        } else {
            Text(account.organizationName ?? account.tierDescription)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }

        Spacer()

        // Right side: Weekly cap status & reset time
        if let wk = account.snapshot.weeklyPercent {
            HStack(spacing: 4) {
                Text("Weekly: \(Int(wk))%")
                    .font(.system(size: 9, weight: wk >= 90 ? .bold : .medium, design: .monospaced))
                    .foregroundColor(wk >= 95 ? .peakRed : (wk >= 80 ? .claudeBrand : .secondary))
                if let wkReset = account.snapshot.weeklyResetFormatted(at: referenceDate) {
                    Text("(\(wkReset))")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("Session Ready")
                .font(.system(size: 9))
                .foregroundColor(.offPeakGreen)
        }
    }

    private var progressFraction: Double {
        switch account.type {
        case .rollingTracker:
            return account.snapshot.usageFraction(at: referenceDate)

        case .anthropicAPI:
            if let limit = account.snapshot.tokensLimit, limit > 0, let remaining = account.snapshot.tokensRemaining {
                let used = max(0, limit - remaining)
                return min(1.0, Double(used) / Double(limit))
            }
            return 0.45

        case .claudeWeb:
            if account.snapshot.isFiveHourExhausted {
                return 1.0
            }
            if let fh = account.snapshot.fiveHourPercent, fh > 0 {
                return min(1.0, fh / 100.0)
            }
            if let wk = account.snapshot.weeklyPercent {
                return min(1.0, wk / 100.0)
            }
            return 0.0
        }
    }

    private func progressBarColor(fraction: Double) -> Color {
        if account.type == .claudeWeb {
            if account.snapshot.isFiveHourExhausted || (account.snapshot.weeklyPercent ?? 0) >= 95.0 {
                return .peakRed
            } else if fraction >= 0.75 {
                return .claudeBrand
            }
        } else if fraction >= 0.9 {
            return .peakRed
        } else if fraction >= 0.75 {
            return .claudeBrand
        }
        return Color(hex: account.colorHex)
    }
}
