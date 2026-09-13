import XCTest
@testable import ClaudeUsageShared

final class AccountStoreTests: XCTestCase {
    var store: AccountStore!
    var testDefaults: UserDefaults!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        let suiteName = "test_claude_suite_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AccountStoreTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        store = AccountStore(userDefaults: testDefaults, customStorageDirectory: tempDirectory)
    }

    override func tearDown() {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        super.tearDown()
    }

    func testAddAndSetPrimaryAccount() {
        let acc1 = ClaudeAccount(
            name: "API Test Org",
            type: .anthropicAPI,
            colorHex: "#CC785C"
        )
        let acc2 = ClaudeAccount(
            name: "Personal Pro",
            type: .rollingTracker,
            colorHex: "#3B82F6"
        )

        store.accounts = []
        store.addAccount(acc1)
        store.addAccount(acc2)

        XCTAssertEqual(store.accounts.count, 2)
        XCTAssertEqual(store.primaryAccount?.id, acc1.id)

        store.setPrimary(accountId: acc2.id)
        XCTAssertEqual(store.primaryAccount?.id, acc2.id)
    }

    func testRollingWindowExpiration() {
        let now = Date()
        var snapshot = UsageSnapshot(rollingLimit: 50, rollingWindowSeconds: 5 * 3600)

        // Add 3 invocations: 1 hour ago, 3 hours ago, and 6 hours ago (outside 5h window)
        snapshot.recentInvocations = [
            now.addingTimeInterval(-1 * 3600),
            now.addingTimeInterval(-3 * 3600),
            now.addingTimeInterval(-6 * 3600)
        ]

        let active = snapshot.activeInvocations(at: now)
        XCTAssertEqual(active.count, 2)
        XCTAssertEqual(snapshot.activeCount(at: now), 2)
        XCTAssertEqual(snapshot.remainingMessages(at: now), 48)
        XCTAssertEqual(snapshot.usageFraction(at: now), 2.0 / 50.0, accuracy: 0.001)

        // Oldest active invocation is 3 hours ago, so next slot frees in 2 hours
        let nextFree = snapshot.nextSlotFreeDate(at: now)
        XCTAssertNotNil(nextFree)
        if let nextFree = nextFree {
            let diff = nextFree.timeIntervalSince(now)
            XCTAssertEqual(Int(diff), 2 * 3600)
        }
    }

    func testWebUsageMetricsCalculation() {
        let now = Date()
        let resets = now.addingTimeInterval(3600)
        let snapshot = UsageSnapshot(
            fiveHourPercent: 100.0,
            fiveHourResetsAt: resets,
            weeklyPercent: 95.0
        )

        XCTAssertTrue(snapshot.hasWebUsageData)
        XCTAssertTrue(snapshot.isFiveHourExhausted)
        XCTAssertFalse(snapshot.isWeeklyExhausted)
        XCTAssertEqual(snapshot.usageFraction(at: now), 1.0)
        XCTAssertNotNil(snapshot.fiveHourResetCountdown(at: now))
    }

    func testFormattingHelpers() {
        var snapshot = UsageSnapshot()
        snapshot.totalCostUSD = 15.755
        XCTAssertEqual(snapshot.formattedCost, "$15.76")

        snapshot.inputTokens = 120_000
        snapshot.outputTokens = 25_000
        XCTAssertEqual(snapshot.formattedTokens, "145.0K")

        snapshot.inputTokens = 1_500_000
        snapshot.outputTokens = 500_000
        XCTAssertEqual(snapshot.formattedTokens, "2.0M")
    }

    func testResetFormatting() {
        let calendar = Calendar.current
        let now = Date()

        // Test same-day reset (e.g. today at 5:30 PM)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 17
        components.minute = 30
        components.second = 0
        if let targetDate = calendar.date(from: components) {
            let formatted = DateFormatting.formatResetTime(targetDate, relativeTo: now, compact: false)
            XCTAssertTrue(formatted.contains("5:30 PM today") || formatted.contains("5:30 today"))
            let compact = DateFormatting.formatResetTime(targetDate, relativeTo: now, compact: true)
            XCTAssertEqual(compact, "5:30 PM today")
        }

        // Test tomorrow reset
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            var tomComp = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            tomComp.hour = 6
            tomComp.minute = 0
            if let tomDate = calendar.date(from: tomComp) {
                let formatted = DateFormatting.formatWeeklyReset(tomDate, relativeTo: now)
                XCTAssertTrue(formatted.contains("6:00 AM"))
            }
        }
    }
}
