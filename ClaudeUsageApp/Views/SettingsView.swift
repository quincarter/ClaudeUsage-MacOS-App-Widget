import ClaudeUsageShared
import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store = AccountStore.shared
    @State private var showingResetAlert = false

    public init() {}

    public var body: some View {
        Form {
            Section("Peak Window Notifications") {
                Toggle("Notify when Peak Hours Start (1:00 PM UTC)", isOn: $store.settings.notifyOnPeakStart)
                    .onChange(of: store.settings.notifyOnPeakStart) { _ in
                        store.saveSettings()
                        updateNotifications()
                    }

                Toggle("Notify when Peak Hours End (7:00 PM UTC)", isOn: $store.settings.notifyOnPeakEnd)
                    .onChange(of: store.settings.notifyOnPeakEnd) { _ in
                        store.saveSettings()
                        updateNotifications()
                    }

                Text("Local notifications are delivered to your Notification Center when entering or exiting peak hours.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section("Display & Timezones") {
                Picker("Timeline Reference Timezone:", selection: $store.settings.targetTimezoneIdentifier) {
                    Text("System Default (\(TimeZone.current.abbreviation() ?? "Local"))").tag(TimeZone.current.identifier)
                    Text("Pacific Time (PT)").tag("America/Los_Angeles")
                    Text("Eastern Time (ET)").tag("America/New_York")
                    Text("Greenwich Mean Time (UTC)").tag("UTC")
                    Text("Central European Time (CET)").tag("Europe/Paris")
                }
                .onChange(of: store.settings.targetTimezoneIdentifier) { _ in
                    store.saveSettings()
                }

                Toggle("Show Dollar Spend in Widget", isOn: $store.settings.showCostInWidget)
                    .onChange(of: store.settings.showCostInWidget) { _ in
                        store.saveSettings()
                    }

                Toggle("Show Token Count in Widget", isOn: $store.settings.showTokensInWidget)
                    .onChange(of: store.settings.showTokensInWidget) { _ in
                        store.saveSettings()
                    }
            }

            Section("Data Management") {
                Button("Reset to Sample Demo Accounts", role: .destructive) {
                    showingResetAlert = true
                }
                .alert("Reset Accounts?", isPresented: $showingResetAlert) {
                    Button("Reset", role: .destructive) {
                        store.accounts = ClaudeAccount.sampleAccounts
                        store.saveAccounts()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This replaces your configured accounts with the initial sample demo accounts.")
                }
            }

            Section("About") {
                HStack(spacing: 14) {
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .cornerRadius(9)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Claude Usage & Peak Intelligence")
                            .font(.system(size: 13, weight: .bold))
                        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
                        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        Text("Version \(version) (Build \(build)) • macOS 14.0+")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("MIT License • Developed with Claude")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle("Preferences")
    }

    private func updateNotifications() {
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            if store.settings.notifyOnPeakStart || store.settings.notifyOnPeakEnd {
                NotificationManager.shared.schedulePeakNotifications()
            }
        }
    }
}
