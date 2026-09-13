import ClaudeUsageShared
import SwiftUI

@main
struct ClaudeUsageApp: App {
    @StateObject private var store = AccountStore.shared
    @State private var currentStatus = PeakTimeEngine.shared.currentStatus()
    let statusTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup("Claude Usage & Peak Intelligence") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                if currentStatus.isPeak {
                    Text("PEAK")
                        .font(.system(size: 9, weight: .black))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
