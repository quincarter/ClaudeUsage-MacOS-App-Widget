import Foundation

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case anthropicAPI = "Anthropic API Key"
    case claudeWeb = "Claude.ai Web Session"
    case rollingTracker = "Rolling 5-Hour Tracker"

    public var systemImage: String {
        switch self {
        case .anthropicAPI:
            return "terminal.fill"
        case .claudeWeb:
            return "network"
        case .rollingTracker:
            return "clock.arrow.2.circlepath"
        }
    }

    public var subtitle: String {
        switch self {
        case .anthropicAPI:
            return "Tracks tokens, spend, and rate limits via Anthropic API"
        case .claudeWeb:
            return "Tracks organization & subscription status via Claude.ai session"
        case .rollingTracker:
            return "Local 5-hour rolling invocation tracker with quick-log"
        }
    }
}
