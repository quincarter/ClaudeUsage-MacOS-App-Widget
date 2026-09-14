import Foundation
import Combine
import Security
#if canImport(WidgetKit)
import WidgetKit
#endif

public final class AccountStore: ObservableObject, @unchecked Sendable {
    public static let shared = AccountStore()

    public static let appGroupIdentifier = "group.com.claudeusage.app"
    private static let accountsKey = "claude_tracked_accounts_v1"
    private static let settingsKey = "claude_app_settings_v1"
    private static let initializedKey = "claude_storage_initialized_v1"
    private static let keychainService = "com.claudeusage.app.credentials"

    @Published public var accounts: [ClaudeAccount] = []
    @Published public var settings: AppSettings = AppSettings()
    @Published public var isRefreshing: Bool = false

    private let userDefaults: UserDefaults
    private let customStorageDirectory: URL?
    private var refreshTimer: Timer?

    /// Permanent storage location in Application Support that survives all Xcode rebuilds & cleans
    private var permanentAppSupportURL: URL {
        if let custom = customStorageDirectory {
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom.appendingPathComponent("accounts.json")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: ("~/Library/Application Support" as NSString).expandingTildeInPath)
        let dir = appSupport.appendingPathComponent("ClaudeUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("accounts.json")
    }

    private var permanentSettingsURL: URL {
        if let custom = customStorageDirectory {
            try? FileManager.default.createDirectory(at: custom, withIntermediateDirectories: true)
            return custom.appendingPathComponent("settings.json")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: ("~/Library/Application Support" as NSString).expandingTildeInPath)
        let dir = appSupport.appendingPathComponent("ClaudeUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    private var sharedDirectoryURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AccountStore.appGroupIdentifier)
    }

    private var accountsFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent("claude_accounts.json")
    }

    private var settingsFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent("claude_settings.json")
    }

    public var isWidgetExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex") || Bundle.main.bundleIdentifier?.contains("widget") == true
    }

    public init(userDefaults: UserDefaults? = nil, customStorageDirectory: URL? = nil) {
        self.customStorageDirectory = customStorageDirectory
        if let custom = userDefaults {
            self.userDefaults = custom
        } else if let suite = UserDefaults(suiteName: AccountStore.appGroupIdentifier) {
            self.userDefaults = suite
        } else {
            self.userDefaults = .standard
        }

        loadSettings()
        loadAccounts()

        // In production app runs (never in widget extensions), automatically trigger background usage sync and setup timer
        if customStorageDirectory == nil && !isWidgetExtension {
            Task { [weak self] in
                await self?.refreshAllAccounts()
            }
            DispatchQueue.main.async { [weak self] in
                self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    Task { [weak self] in
                        await self?.refreshAllAccounts()
                    }
                }
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    public func loadAccounts() {
        if isWidgetExtension {
            // WIDGET EXTENSION READ-ONLY FLOW:
            // Priority 1: Widget container's own Application Support file (direct local access within sandbox)
            if FileManager.default.fileExists(atPath: permanentAppSupportURL.path) {
                if let data = try? Data(contentsOf: permanentAppSupportURL),
                   let decoded = try? JSONDecoder().decode([ClaudeAccount].self, from: data),
                   !decoded.isEmpty {
                    self.accounts = decoded
                    NSLog("[ClaudeUsageWidget] Loaded %ld accounts from widget container App Support: %@", decoded.count, permanentAppSupportURL.path)
                    return
                }
            }

            // Priority 2: Shared Group Container File
            if let fileURL = accountsFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
                if let data = try? Data(contentsOf: fileURL),
                   let decoded = try? JSONDecoder().decode([ClaudeAccount].self, from: data),
                   !decoded.isEmpty {
                    self.accounts = decoded
                    NSLog("[ClaudeUsageWidget] Loaded %ld accounts from shared group container file", decoded.count)
                    return
                }
            }

            // Priority 3: Shared UserDefaults suite
            if let data = userDefaults.data(forKey: AccountStore.accountsKey),
               let decoded = try? JSONDecoder().decode([ClaudeAccount].self, from: data),
               !decoded.isEmpty {
                self.accounts = decoded
                NSLog("[ClaudeUsageWidget] Loaded %ld accounts from shared UserDefaults", decoded.count)
                return
            }

            // Priority 4: Widget container preferences plist
            let plistURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Preferences/group.com.claudeusage.app.plist")
            if let plistPath = plistURL?.path, FileManager.default.fileExists(atPath: plistPath),
               let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any],
               let data = dict[AccountStore.accountsKey] as? Data,
               let decoded = try? JSONDecoder().decode([ClaudeAccount].self, from: data),
               !decoded.isEmpty {
                self.accounts = decoded
                NSLog("[ClaudeUsageWidget] Loaded %ld accounts from widget container plist", decoded.count)
                return
            }

            NSLog("[ClaudeUsageWidget] Warning: No accounts found in any storage. Current count: %ld", self.accounts.count)
            return
        }

        // HOST APPLICATION FLOW:
        // Priority 1: Permanent Master File in Application Support (survives rebuilds, clean builds, reinstall)
        if FileManager.default.fileExists(atPath: permanentAppSupportURL.path) {
            do {
                let data = try Data(contentsOf: permanentAppSupportURL)
                let decoded = try JSONDecoder().decode([ClaudeAccount].self, from: data)
                self.accounts = decoded
                syncToOtherStorages(data: data)
                return
            } catch {
                print("Failed to decode accounts from permanent App Support: \(error)")
            }
        }

        // Priority 2: Shared Group Container File
        if let fileURL = accountsFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([ClaudeAccount].self, from: data)
                self.accounts = decoded
                syncToOtherStorages(data: data)
                return
            } catch {
                print("Failed to decode accounts from shared group file: \(error)")
            }
        }

        // Priority 3: UserDefaults
        if let data = userDefaults.data(forKey: AccountStore.accountsKey) {
            do {
                let decoded = try JSONDecoder().decode([ClaudeAccount].self, from: data)
                self.accounts = decoded
                syncToOtherStorages(data: data)
                return
            } catch {
                print("Failed to decode saved accounts from UserDefaults: \(error)")
            }
        }

        // Priority 4: Existing App Sandbox preferences (from earlier runs)
        let appSandboxPlist = ("~/Library/Containers/com.claudeusage.app/Data/Library/Preferences/group.com.claudeusage.app.plist" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: appSandboxPlist),
           let dict = NSDictionary(contentsOfFile: appSandboxPlist) as? [String: Any],
           let data = dict[AccountStore.accountsKey] as? Data {
            do {
                let decoded = try JSONDecoder().decode([ClaudeAccount].self, from: data)
                self.accounts = decoded
                syncToOtherStorages(data: data)
                return
            } catch {
                print("Failed to decode from app container plist: \(error)")
            }
        }

        // Priority 5: Widget container preferences
        let widgetPlist = ("~/Library/Containers/com.claudeusage.app.widget/Data/Library/Preferences/group.com.claudeusage.app.plist" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: widgetPlist),
           let dict = NSDictionary(contentsOfFile: widgetPlist) as? [String: Any],
           let data = dict[AccountStore.accountsKey] as? Data {
            do {
                let decoded = try JSONDecoder().decode([ClaudeAccount].self, from: data)
                self.accounts = decoded
                syncToOtherStorages(data: data)
                return
            } catch {
                print("Failed to decode from widget plist: \(error)")
            }
        }

        // Only initialize with sample accounts if NEVER initialized before
        let isInitialized = userDefaults.bool(forKey: AccountStore.initializedKey)
        if !isInitialized {
            self.accounts = ClaudeAccount.sampleAccounts
            saveAccounts()
            userDefaults.set(true, forKey: AccountStore.initializedKey)
        } else {
            self.accounts = []
        }
    }

    public func saveAccounts() {
        do {
            let data = try JSONEncoder().encode(accounts)
            syncToOtherStorages(data: data)

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            print("Failed to encode accounts: \(error)")
        }
    }

    private func syncToOtherStorages(data: Data) {
        // Widget extension is read-only and must never overwrite master storages
        if isWidgetExtension { return }

        // 1. Permanent Master Application Support file
        try? data.write(to: permanentAppSupportURL, options: .atomic)

        // If in test isolation mode, don't write to shared system containers
        if customStorageDirectory != nil {
            userDefaults.set(data, forKey: AccountStore.accountsKey)
            userDefaults.synchronize()
            return
        }

        // 2. Shared Group Directory file
        if let fileURL = accountsFileURL {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }

        // 3. Widget container Application Support (direct sync into widget container)
        let widgetAppSupport = ("~/Library/Containers/com.claudeusage.app.widget/Data/Library/Application Support/ClaudeUsage" as NSString).expandingTildeInPath
        let widgetAccountsFile = (widgetAppSupport as NSString).appendingPathComponent("accounts.json")
        try? FileManager.default.createDirectory(atPath: widgetAppSupport, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: widgetAccountsFile), options: .atomic)

        // 4. Widget sandbox container plist (direct cross-container sync)
        let widgetContainerDir = ("~/Library/Containers/com.claudeusage.app.widget/Data/Library/Preferences" as NSString).expandingTildeInPath
        let widgetContainerPlist = (widgetContainerDir as NSString).appendingPathComponent("group.com.claudeusage.app.plist")
        if FileManager.default.fileExists(atPath: widgetContainerDir) {
            let dict: [String: Any] = [
                AccountStore.accountsKey: data,
                AccountStore.initializedKey: true
            ]
            (dict as NSDictionary).write(toFile: widgetContainerPlist, atomically: true)
        }

        // 5. UserDefaults
        userDefaults.set(data, forKey: AccountStore.accountsKey)
        userDefaults.set(true, forKey: AccountStore.initializedKey)
        userDefaults.synchronize()

        // 6. Notify WidgetCenter immediately so all active widgets re-read latest data
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public func loadSettings() {
        if FileManager.default.fileExists(atPath: permanentSettingsURL.path) {
            do {
                let data = try Data(contentsOf: permanentSettingsURL)
                let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
                self.settings = decoded
                return
            } catch {
                print("Failed to decode settings from App Support: \(error)")
            }
        }

        if let fileURL = settingsFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
                self.settings = decoded
                return
            } catch {
                print("Failed to decode settings from shared file: \(error)")
            }
        }

        if let data = userDefaults.data(forKey: AccountStore.settingsKey) {
            do {
                let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
                self.settings = decoded
                return
            } catch {
                print("Failed to decode settings: \(error)")
            }
        }
        self.settings = AppSettings()
    }

    public func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)

            try? data.write(to: permanentSettingsURL, options: .atomic)

            if customStorageDirectory == nil {
                if let fileURL = settingsFileURL {
                    try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? data.write(to: fileURL, options: .atomic)
                }
            }

            userDefaults.set(data, forKey: AccountStore.settingsKey)
            userDefaults.synchronize()

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }

    public var primaryAccount: ClaudeAccount? {
        accounts.first { $0.isPrimary } ?? accounts.first
    }

    public func setPrimary(accountId: UUID) {
        for index in accounts.indices {
            accounts[index].isPrimary = (accounts[index].id == accountId)
        }
        saveAccounts()
    }

    public func addAccount(_ account: ClaudeAccount, credentialSecret: String? = nil) {
        var newAccount = account
        if accounts.isEmpty {
            newAccount.isPrimary = true
        }
        accounts.append(newAccount)
        saveAccounts()

        if let secret = credentialSecret, !secret.isEmpty {
            saveCredential(accountKey: newAccount.id.uuidString, secret: secret)
        }

        Task { [weak self] in
            await self?.refreshAllAccounts()
        }
    }

    public func updateAccount(_ account: ClaudeAccount, credentialSecret: String? = nil) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()

            if let secret = credentialSecret, !secret.isEmpty {
                saveCredential(accountKey: account.id.uuidString, secret: secret)
            }

            Task { [weak self] in
                await self?.refreshAllAccounts()
            }
        }
    }

    public func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        if !accounts.isEmpty && !accounts.contains(where: { $0.isPrimary }) {
            accounts[0].isPrimary = true
        }
        saveAccounts()
        deleteCredential(accountKey: id.uuidString)
    }

    public func recordInvocation(for accountId: UUID, at date: Date = Date()) {
        if let index = accounts.firstIndex(where: { $0.id == accountId }) {
            accounts[index].recordInvocation(at: date)
            saveAccounts()
        }
    }

    // MARK: - Usage Synchronization

    public func refreshAccountUsage(account: ClaudeAccount) async -> ClaudeAccount {
        var updated = account

        switch account.type {
        case .claudeWeb:
            let secret = loadCredential(accountKey: account.id.uuidString)
            if let sessionKey = secret, !sessionKey.isEmpty {
                do {
                    let (usageData, orgId, orgName, tier) = try await ClaudeWebService.shared.fetchUsage(
                        sessionKey: sessionKey,
                        orgId: account.organizationId
                    )
                    updated.organizationId = orgId
                    if let name = orgName { updated.organizationName = name }
                    updated.tierDescription = tier
                    updated.snapshot.fiveHourPercent = usageData.fiveHourPercent
                    updated.snapshot.fiveHourResetsAt = usageData.fiveHourResetsAt
                    updated.snapshot.weeklyPercent = usageData.weeklyPercent
                    updated.snapshot.weeklyResetsAt = usageData.weeklyResetsAt
                    updated.snapshot.extraUsagePercent = usageData.extraUsagePercent
                    updated.snapshot.activeLimitKind = usageData.activeLimitKind
                    updated.snapshot.sevenDayBreakdown = usageData.sevenDayBreakdown
                    updated.lastSync = Date()
                    return updated
                } catch {
                    print("Network usage fetch failed for \(account.name): \(error). Attempting local fallback.")
                }
            }

            // Fallback to local ~/.claude-instances history
            if let local = ClaudeWebService.shared.fetchLocalInstanceUsage(accountName: account.name, orgId: account.organizationId) {
                updated.snapshot.fiveHourPercent = local.fiveHourPercent
                updated.snapshot.weeklyPercent = local.weeklyPercent
                updated.snapshot.extraUsagePercent = local.extraUsagePercent
                updated.snapshot.activeLimitKind = local.activeLimitKind
                updated.lastSync = Date()
            }

        case .anthropicAPI:
            // Handled via AnthropicUsageService if configured
            break

        case .rollingTracker:
            break
        }

        return updated
    }

    @MainActor
    public func refreshAllAccounts() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var refreshedAccounts: [ClaudeAccount] = []
        for account in accounts {
            let refreshed = await refreshAccountUsage(account: account)
            refreshedAccounts.append(refreshed)
        }

        self.accounts = refreshedAccounts
        saveAccounts()
    }

    // MARK: - Keychain Security

    public func saveCredential(accountKey: String, secret: String) {
        guard let data = secret.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AccountStore.keychainService,
            kSecAttrAccount as String: accountKey
        ]

        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    public func loadCredential(accountKey: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AccountStore.keychainService,
            kSecAttrAccount as String: accountKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteCredential(accountKey: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AccountStore.keychainService,
            kSecAttrAccount as String: accountKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}
