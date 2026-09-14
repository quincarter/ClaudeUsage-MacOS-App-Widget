import ClaudeUsageShared
import SwiftUI

public struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = AccountStore.shared
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var status: PeakStatus {
        PeakTimeEngine.shared.currentStatus(at: currentTime)
    }

    var slice: DayTimelineSlice {
        PeakTimeEngine.shared.dayTimelineSlice(for: currentTime)
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Peak Status Pill
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(status.isPeak ? Color.peakRed : Color.offPeakGreen)
                        .frame(width: 8, height: 8)

                    Text(status.statusTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(status.isPeak ? Color.peakRed : Color.offPeakGreen)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(status.statusSubheading)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((status.isPeak ? Color.peakRed : Color.offPeakGreen).opacity(0.15))
                .cornerRadius(6)

                Spacer()

                Button(action: {
                    currentTime = Date()
                    Task {
                        await store.refreshAllAccounts()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Timeline bar
            PeakTimelineBar(slice: slice, height: 12, showLabels: true)

            Divider()

            // Accounts Quick List
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CLAUDE ACCOUNTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()

                    // Quick "+1 Invocation" on primary rolling account
                    if let primary = store.primaryAccount {
                        Button(action: {
                            store.recordInvocation(for: primary.id)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 10))
                                Text("+1 Prompt")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.claudeBrand.opacity(0.15))
                            .foregroundColor(.claudeBrand)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.accounts.isEmpty {
                    Text("No accounts configured yet.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.accounts) { account in
                        AccountUsageRow(account: account, referenceDate: currentTime, compact: true)
                    }
                }
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")

                    for window in NSApp.windows where window.identifier?.rawValue == "dashboard" || (window.title.contains("Claude") && !window.className.contains("StatusBar") && !window.className.contains("Panel")) {
                        if window.isMiniaturized {
                            window.deminiaturize(nil)
                        }
                        window.makeKeyAndOrderFront(nil)
                    }

                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 320)
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
    }
}
