import XCTest
import SwiftUI
import AppKit
@testable import ClaudeUsageShared

final class ScreenshotGeneratorTests: XCTestCase {

    @MainActor
    func testGenerateAllScreenshots() throws {
        let projectDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // Project root
        let screenshotsDir = projectDir.appendingPathComponent("assets/screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        let calendar = Calendar.current
        let now = Date()

        // Calculate a 5:30 PM reset time for today
        var comp = calendar.dateComponents([.year, .month, .day], from: now)
        comp.hour = 17
        comp.minute = 30
        let reset530Today = calendar.date(from: comp) ?? now.addingTimeInterval(3600 * 3)

        // Calculate Friday 6:00 AM reset
        var friComp = calendar.dateComponents([.year, .month, .day], from: now)
        friComp.day = (friComp.day ?? 1) + 4
        friComp.hour = 6
        friComp.minute = 0
        friComp.second = 0
        let friReset = calendar.date(from: friComp) ?? now.addingTimeInterval(3600 * 24 * 4)

        // 1. Scrubbed Mock Accounts (100% anonymized, realistic, clean)
        let account1 = ClaudeAccount(
            name: "Claude Pro",
            type: .claudeWeb,
            colorHex: "#CC785C", // Claude Terracotta
            isPrimary: true,
            tierDescription: "Claude Pro",
            organizationName: "Acme Workspace",
            snapshot: UsageSnapshot(
                fiveHourPercent: 100.0,
                fiveHourResetsAt: reset530Today,
                weeklyPercent: 42.0,
                weeklyResetsAt: friReset
            )
        )

        let account2 = ClaudeAccount(
            name: "Engineering API",
            type: .anthropicAPI,
            colorHex: "#6366F1", // Indigo
            isPrimary: false,
            tierDescription: "Scale Tier",
            organizationName: "Production Cluster",
            snapshot: UsageSnapshot(
                inputTokens: 3_250_000,
                outputTokens: 920_000,
                totalCostUSD: 34.80,
                requestsRemaining: 3850
            )
        )

        let account3 = ClaudeAccount(
            name: "Claude Code Agent",
            type: .claudeWeb,
            colorHex: "#10B981", // Emerald
            isPrimary: false,
            tierDescription: "Claude Team",
            organizationName: "Developer Sandbox",
            snapshot: UsageSnapshot(
                fiveHourPercent: 15.0,
                fiveHourResetsAt: nil,
                weeklyPercent: 95.0,
                weeklyResetsAt: friReset,
                sevenDayBreakdown: ["Claude Code": 82.0, "Chat": 12.0, "Artifacts": 6.0]
            )
        )

        let scrubbedAccounts = [account1, account2, account3]

        // 2. Timeline Slice & Status (Off-Peak window starting in 2h 15m)
        let mockStatus = PeakStatus.offPeak(
            nextStartsAt: now.addingTimeInterval(3600 * 2 + 900),
            timeUntilNext: 3600 * 2 + 900
        )

        let mockSlice = DayTimelineSlice(
            peakStartFraction: 8.0 / 24.0,
            peakEndFraction: 14.0 / 24.0,
            currentFraction: 5.75 / 24.0,
            hasPeakToday: true,
            localStartString: "8:00 AM",
            localEndString: "2:00 PM"
        )

        let entry = ClaudeUsageEntry(
            date: now,
            status: mockStatus,
            slice: mockSlice,
            accounts: scrubbedAccounts,
            primaryAccount: account1
        )

        // 3. Render Small Widget (155 x 155 pt)
        let smallWidget = widgetWrapper(width: 155, height: 155) {
            SmallWidgetView(entry: entry)
        }
        try renderView(smallWidget, size: CGSize(width: 175, height: 175), to: screenshotsDir.appendingPathComponent("widget-small.png"))

        // 4. Render Medium Widget (329 x 155 pt)
        let mediumWidget = widgetWrapper(width: 329, height: 155) {
            MediumWidgetView(entry: entry)
        }
        try renderView(mediumWidget, size: CGSize(width: 349, height: 175), to: screenshotsDir.appendingPathComponent("widget-medium.png"))

        // 5. Render Large Widget (329 x 345 pt)
        let largeWidget = widgetWrapper(width: 329, height: 345) {
            LargeWidgetView(entry: entry)
        }
        try renderView(largeWidget, size: CGSize(width: 349, height: 365), to: screenshotsDir.appendingPathComponent("widget-large.png"))

        // 6. Render App Window Mockup (860 x 540 pt)
        let appWindow = macOSWindowWrapper(title: "Claude Usage — Rate Limits & Peak Horizon", width: 860, height: 540) {
            DashboardMockContentView(status: mockStatus, slice: mockSlice, accounts: scrubbedAccounts)
        }
        try renderView(appWindow, size: CGSize(width: 888, height: 568), to: screenshotsDir.appendingPathComponent("app-dashboard.png"))

        // 7. Render Menu Bar Popup (320 x 290 pt)
        let menuBarPopup = menuBarPopoverWrapper(width: 320, height: 290) {
            MenuBarMockContentView(status: mockStatus, slice: mockSlice, accounts: scrubbedAccounts)
        }
        try renderView(menuBarPopup, size: CGSize(width: 340, height: 310), to: screenshotsDir.appendingPathComponent("menubar-popup.png"))

        print("Successfully generated all screenshots in:", screenshotsDir.path)
    }

    @MainActor
    private func renderView<V: View>(_ view: V, size: CGSize, to url: URL) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2.0 // @2x Retina resolution
        guard let nsImage = renderer.nsImage else {
            XCTFail("Failed to render NSImage for: \(url.lastPathComponent)")
            return
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG for: \(url.lastPathComponent)")
            return
        }

        try pngData.write(to: url)
        print("Saved screenshot:", url.lastPathComponent, "size:", "\(Int(size.width * 2))x\(Int(size.height * 2))")
    }

    private func widgetWrapper<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> some View {
        content()
            .frame(width: width, height: height)
            .background(Color(red: 0.12, green: 0.13, blue: 0.15))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
            .padding(10)
            .environment(\.colorScheme, .dark)
    }

    private func menuBarPopoverWrapper<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 7)
        .padding(10)
        .environment(\.colorScheme, .dark)
    }

    private func macOSWindowWrapper<V: View>(title: String, width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> some View {
        VStack(spacing: 0) {
            // Window Title Bar
            HStack(spacing: 8) {
                // Traffic light buttons
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#FF5F56")).frame(width: 12, height: 12)
                    Circle().fill(Color(hex: "#FFBD2E")).frame(width: 12, height: 12)
                    Circle().fill(Color(hex: "#27C93F")).frame(width: 12, height: 12)
                }
                .padding(.leading, 12)

                Spacer()

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))

                Spacer()

                Color.clear.frame(width: 50, height: 12)
            }
            .frame(height: 38)
            .background(Color(red: 0.14, green: 0.15, blue: 0.18))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.08)),
                alignment: .bottom
            )

            // Window Content
            content()
        }
        .frame(width: width, height: height)
        .background(Color(red: 0.10, green: 0.11, blue: 0.13))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        .padding(14)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Dedicated Mock Views

struct DashboardMockContentView: View {
    let status: PeakStatus
    let slice: DayTimelineSlice
    let accounts: [ClaudeAccount]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MONITOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "gauge.with.needle.fill")
                            .foregroundColor(.claudeBrand)
                        Text("Live Dashboard")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)

                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.gray)
                        Text("Peak Schedule")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MANAGEMENT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.gray)
                        Text("Claude Accounts (3)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)

                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.gray)
                        Text("Preferences")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                }

                Spacer()
            }
            .padding(14)
            .frame(width: 200)
            .background(Color(red: 0.12, green: 0.13, blue: 0.16))
            .overlay(
                Rectangle().frame(width: 1).foregroundColor(Color.white.opacity(0.08)),
                alignment: .trailing
            )

            // Main Dashboard Detail
            VStack(alignment: .leading, spacing: 14) {
                // Header Banner
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.offPeakGreen).frame(width: 8, height: 8)
                            Text("OFF-PEAK — Starts in 2h 15m")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.offPeakGreen)
                        }
                        Text("Standard limits and maximum token generation performance active.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Usage")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                }
                .padding(12)
                .background(Color.offPeakGreen.opacity(0.12))
                .cornerRadius(8)

                // Timeline
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("24-Hour Peak Horizon")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Weekdays 5:00 AM – 11:00 AM (PT)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    PeakTimelineBar(slice: slice, height: 16, showLabels: true)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)

                // Accounts Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE CLAUDE ACCOUNTS (3)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)

                    ForEach(accounts) { acc in
                        AccountUsageRow(account: acc, referenceDate: Date(), compact: false)
                    }
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.10, green: 0.11, blue: 0.13))
        }
    }
}

struct MenuBarMockContentView: View {
    let status: PeakStatus
    let slice: DayTimelineSlice
    let accounts: [ClaudeAccount]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.offPeakGreen).frame(width: 8, height: 8)
                    Text("OFF-PEAK • Starts in 2h 15m")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.offPeakGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.offPeakGreen.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            // Timeline
            PeakTimelineBar(slice: slice, height: 12, showLabels: true)

            Divider().overlay(Color.white.opacity(0.1))

            // Accounts
            Text("CLAUDE ACCOUNTS (3)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)

            VStack(spacing: 6) {
                ForEach(accounts) { acc in
                    AccountUsageRow(account: acc, referenceDate: Date(), compact: true)
                }
            }

            Divider().overlay(Color.white.opacity(0.1))

            HStack {
                Text("Open Full Dashboard")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text("⌘O")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
    }
}
