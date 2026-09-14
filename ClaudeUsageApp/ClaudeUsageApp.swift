import AppKit
import ClaudeUsageShared
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.identifier?.rawValue == "dashboard" || (window.title.contains("Claude") && !window.className.contains("StatusBar") && !window.className.contains("Panel")) {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }
}

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = AccountStore.shared
    @State private var currentStatus = PeakTimeEngine.shared.currentStatus()
    let statusTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some Scene {
        Window("Claude Usage & Peak Intelligence", id: "dashboard") {
            DashboardView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(store)
                .onReceive(statusTimer) { _ in
                    currentStatus = PeakTimeEngine.shared.currentStatus()
                }
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
