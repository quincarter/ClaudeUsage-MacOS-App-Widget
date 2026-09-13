import Foundation

public struct ClaudeAccount: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var type: AccountType
    public var colorHex: String
    public var isPrimary: Bool
    public var tierDescription: String
    public var organizationName: String?
    public var organizationId: String?
    public var lastSync: Date?
    public var snapshot: UsageSnapshot

    public init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        colorHex: String = "#D97706", // warm amber/claude color
        isPrimary: Bool = false,
        tierDescription: String = "Claude Pro",
        organizationName: String? = nil,
        organizationId: String? = nil,
        lastSync: Date? = nil,
        snapshot: UsageSnapshot = UsageSnapshot()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.colorHex = colorHex
        self.isPrimary = isPrimary
        self.tierDescription = tierDescription
        self.organizationName = organizationName
        self.organizationId = organizationId
        self.lastSync = lastSync
        self.snapshot = snapshot
    }

    /// Logs an invocation timestamp
    public mutating func recordInvocation(at date: Date = Date()) {
        snapshot.recentInvocations.append(date)
        // Clean up invocations older than rollingWindowSeconds + 1 hour
        let cutoff = date.addingTimeInterval(-(snapshot.rollingWindowSeconds + 3600))
        snapshot.recentInvocations = snapshot.recentInvocations.filter { $0 > cutoff }
        lastSync = date
    }

    public static var sampleAccounts: [ClaudeAccount] {
        let now = Date()
        let sampleInvocations: [Date] = [
            now.addingTimeInterval(-4 * 3600),
            now.addingTimeInterval(-3 * 3600),
            now.addingTimeInterval(-2.5 * 3600),
            now.addingTimeInterval(-2 * 3600),
            now.addingTimeInterval(-1.5 * 3600),
            now.addingTimeInterval(-45 * 60),
            now.addingTimeInterval(-20 * 60),
            now.addingTimeInterval(-5 * 60)
        ]

        return [
            ClaudeAccount(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Work Dev (API)",
                type: .anthropicAPI,
                colorHex: "#CC785C", // Claude terra cotta
                isPrimary: true,
                tierDescription: "Scale Tier 4",
                organizationName: "Dev Engineering Org",
                lastSync: now.addingTimeInterval(-600),
                snapshot: UsageSnapshot(
                    inputTokens: 482_100,
                    outputTokens: 118_400,
                    totalCostUSD: 14.85,
                    requestsRemaining: 3950,
                    requestsLimit: 4000,
                    tokensRemaining: 380_000,
                    tokensLimit: 400_000,
                    recentInvocations: sampleInvocations,
                    rollingLimit: 50
                )
            ),
            ClaudeAccount(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Personal (Claude Pro)",
                type: .rollingTracker,
                colorHex: "#3B82F6", // Blue
                isPrimary: false,
                tierDescription: "Claude Pro Subscriber",
                organizationName: "Personal Workspace",
                lastSync: now.addingTimeInterval(-120),
                snapshot: UsageSnapshot(
                    inputTokens: 0,
                    outputTokens: 0,
                    totalCostUSD: 20.00,
                    recentInvocations: [
                        now.addingTimeInterval(-2.5 * 3600),
                        now.addingTimeInterval(-2 * 3600),
                        now.addingTimeInterval(-1 * 3600),
                        now.addingTimeInterval(-15 * 60)
                    ],
                    rollingLimit: 45
                )
            ),
            ClaudeAccount(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Research Org (Team)",
                type: .claudeWeb,
                colorHex: "#10B981", // Emerald
                isPrimary: false,
                tierDescription: "Team Plan",
                organizationName: "AI Research Lab",
                lastSync: now.addingTimeInterval(-1800),
                snapshot: UsageSnapshot(
                    inputTokens: 125_000,
                    outputTokens: 35_000,
                    totalCostUSD: 0.0,
                    recentInvocations: sampleInvocations,
                    rollingLimit: 100
                )
            )
        ]
    }
}
