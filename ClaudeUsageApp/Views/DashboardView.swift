import ClaudeUsageShared
import SwiftUI

public struct DashboardView: View {
    @ObservedObject var store = AccountStore.shared
    @State private var currentTime = Date()
    @State private var selectedTab: DashboardTab = .dashboard
    @State private var showingAddAccountSheet = false
    @State private var accountToEdit: ClaudeAccount?

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var status: PeakStatus {
        PeakTimeEngine.shared.currentStatus(at: currentTime)
    }

    var slice: DayTimelineSlice {
        PeakTimeEngine.shared.dayTimelineSlice(for: currentTime, targetTimezone: store.settings.effectiveTimezone)
    }

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Monitor") {
                    NavigationLink(value: DashboardTab.dashboard) {
                        Label("Live Dashboard", systemImage: "gauge.with.needle.fill")
                    }
                    NavigationLink(value: DashboardTab.peakSchedule) {
                        Label("Peak Time Schedule", systemImage: "clock.badge.exclamationmark")
                    }
                }

                Section("Management") {
                    NavigationLink(value: DashboardTab.accounts) {
                        Label("Claude Accounts (\(store.accounts.count))", systemImage: "person.2.fill")
                    }
                    NavigationLink(value: DashboardTab.settings) {
                        Label("Preferences", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selectedTab {
                case .dashboard:
                    dashboardContent
                case .peakSchedule:
                    PeakScheduleView()
                case .accounts:
                    AccountManagerView(showingAddSheet: $showingAddAccountSheet, editingAccount: $accountToEdit)
                case .settings:
                    SettingsView()
                }
            }
            .frame(minWidth: 550, minHeight: 450)
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            AccountEditSheet(account: nil) { newAccount, secret in
                store.addAccount(newAccount, credentialSecret: secret)
            }
        }
        .sheet(item: $accountToEdit) { account in
            AccountEditSheet(account: account) { updatedAccount, secret in
                store.updateAccount(updatedAccount, credentialSecret: secret)
            }
        }
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
        .onAppear {
            currentTime = Date()
            Task {
                await store.refreshAllAccounts()
            }
        }
        .background(WindowAccessor { window in
            window.isReleasedWhenClosed = false
            window.delegate = DashboardWindowDelegate.shared
        })
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Peak Status Hero Banner
                peakHeroBanner

                // 24h Timeline Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("24-Hour Day Timeline")
                            .font(.system(size: 14, weight: .bold))

                        Spacer()

                        Text("Timezone: \(store.settings.effectiveTimezone.abbreviation() ?? "Local")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    PeakTimelineBar(slice: slice, height: 18, showLabels: true)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(10)

                // Accounts Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Configured Accounts")
                            .font(.system(size: 14, weight: .bold))

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await store.refreshAllAccounts()
                                }
                            }) {
                                if store.isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                } else {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(store.isRefreshing)

                            Button(action: {
                                showingAddAccountSheet = true
                            }) {
                                Label("Add Account", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.claudeBrand)
                            .controlSize(.small)
                        }
                    }

                    if store.accounts.isEmpty {
                        emptyAccountsPlaceholder
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(store.accounts) { account in
                                accountDashboardCard(account)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Claude Usage & Peak Intelligence")
    }

    private var peakHeroBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.15))
                    .frame(width: 56, height: 56)

                Circle()
                    .fill(status.isPeak ? Color.peakRed : Color.offPeakGreen)
                    .frame(width: 24, height: 24)

                Image(systemName: status.isPeak ? "flame.fill" : "bolt.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(status.statusTitle)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(status.isPeak ? Color.peakRed : Color.offPeakGreen)

                    Text("•")
                        .foregroundColor(.secondary)

                    PeakStatusLiveSubheadingView(status: status)
                        .font(.system(size: 15, weight: .semibold))
                }

                Text(status.isPeak
                     ? "Peak hours (weekdays 1pm–7pm UTC) — session limits drain faster than usual. Weekly limits unchanged."
                     : "Claude is operating in standard off-peak conditions with normal message capacity and fast generation speeds.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background((status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private func accountDashboardCard(_ account: ClaudeAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text(account.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)

                    Text(account.tierDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if account.isPrimary {
                    Text("PRIMARY")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.claudeBrand.opacity(0.15))
                        .foregroundColor(.claudeBrand)
                        .cornerRadius(4)
                }

                Menu {
                    Button("Set as Primary") {
                        store.setPrimary(accountId: account.id)
                    }
                    Button("Edit Account...") {
                        accountToEdit = account
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        store.deleteAccount(id: account.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
            }

            Divider()

            // Metrics
            VStack(alignment: .leading, spacing: 6) {
                switch account.type {
                case .anthropicAPI:
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Spend")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(account.snapshot.formattedCost)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Tokens")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(account.snapshot.formattedTokens)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                    }
                case .rollingTracker:
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Messages Used (5h)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("\(account.snapshot.activeCount(at: currentTime)) / \(account.snapshot.rollingLimit)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Button(action: {
                            store.recordInvocation(for: account.id)
                        }) {
                            Label("+1 Prompt", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                case .claudeWeb:
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("5-Hour Rolling Limit")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                if account.snapshot.isFiveHourExhausted {
                                    Text("100% (Limit Reached)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.peakRed)
                                } else if let fh = account.snapshot.fiveHourPercent {
                                    Text("\(Int(fh))% Used")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(fh >= 80 ? .claudeBrand : .primary)
                                } else {
                                    Text("Available")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.offPeakGreen)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Weekly Cap (7-Day)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                if let wk = account.snapshot.weeklyPercent {
                                    Text("\(Int(wk))% Used")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(wk >= 95 ? .peakRed : (wk >= 80 ? .claudeBrand : .primary))
                                } else {
                                    Text("Standard")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Breakdown tags if available (e.g. Claude Code 89%)
                        if let breakdown = account.snapshot.sevenDayBreakdown, !breakdown.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(breakdown.keys.sorted()), id: \.self) { key in
                                    if let pct = breakdown[key], pct > 0 {
                                        Text("\(key): \(Int(pct))%")
                                            .font(.system(size: 8, weight: .semibold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.12))
                                            .cornerRadius(3)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Progress bar & detail row
            AccountUsageRow(account: account, referenceDate: currentTime, compact: false)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }

    private var emptyAccountsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No Claude Accounts Added")
                .font(.system(size: 14, weight: .semibold))
            Text("Add an Anthropic API key, Claude.ai web session, or rolling invocation tracker to monitor your usage alongside peak hours.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            Button("Add First Account") {
                showingAddAccountSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.claudeBrand)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
    }
}

enum DashboardTab: Hashable {
    case dashboard
    case peakSchedule
    case accounts
    case settings
}

// MARK: - Window Management Helpers

final class DashboardWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = DashboardWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
