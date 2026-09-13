import ClaudeUsageShared
import SwiftUI

public struct AccountManagerView: View {
    @ObservedObject var store = AccountStore.shared
    @Binding var showingAddSheet: Bool
    @Binding var editingAccount: ClaudeAccount?

    public init(showingAddSheet: Binding<Bool>, editingAccount: Binding<ClaudeAccount?>) {
        self._showingAddSheet = showingAddSheet
        self._editingAccount = editingAccount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Claude Accounts")
                        .font(.system(size: 18, weight: .bold))
                    Text("Configure multiple API keys, Claude.ai web sessions, or 5-hour rolling trackers.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    showingAddSheet = true
                }) {
                    Label("Add Account", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.claudeBrand)
            }

            Divider()

            if store.accounts.isEmpty {
                VStack(spacing: 10) {
                    Text("No accounts configured yet.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.accounts) { account in
                        accountRow(account)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }

    private func accountRow(_ account: ClaudeAccount) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: account.colorHex))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.system(size: 14, weight: .bold))

                    if account.isPrimary {
                        Text("PRIMARY WIDGET ACCOUNT")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.claudeBrand.opacity(0.15))
                            .foregroundColor(.claudeBrand)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Label(account.type.rawValue, systemImage: account.type.systemImage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(account.tierDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !account.isPrimary {
                Button("Make Primary") {
                    store.setPrimary(accountId: account.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("Edit") {
                editingAccount = account
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive, action: {
                store.deleteAccount(id: account.id)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

public struct AccountEditSheet: View {
    @Environment(\.dismiss) var dismiss
    public let account: ClaudeAccount?
    public let onSave: (ClaudeAccount, String?) -> Void

    @State private var name: String
    @State private var type: AccountType
    @State private var colorHex: String
    @State private var tierDescription: String
    @State private var secretKey: String = ""
    @State private var rollingLimit: Int = 45
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSuccess: Bool = false
    @State private var detectedOrgId: String?
    @State private var detectedOrgName: String?

    let availableColors: [String] = [
        "#CC785C", // Claude Terracotta
        "#3B82F6", // Blue
        "#10B981", // Emerald
        "#8B5CF6", // Purple
        "#F59E0B", // Amber
        "#EC4899", // Pink
        "#06B6D4"  // Cyan
    ]

    public init(account: ClaudeAccount?, onSave: @escaping (ClaudeAccount, String?) -> Void) {
        self.account = account
        self.onSave = onSave

        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .anthropicAPI)
        _colorHex = State(initialValue: account?.colorHex ?? "#CC785C")
        _tierDescription = State(initialValue: account?.tierDescription ?? "Claude Pro")
        _rollingLimit = State(initialValue: account?.snapshot.rollingLimit ?? 45)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(account == nil ? "Add Claude Account" : "Edit Claude Account")
                .font(.system(size: 18, weight: .bold))

            Form {
                TextField("Account Label:", text: $name, prompt: Text("e.g. Work API, Personal Pro"))

                Picker("Account Type:", selection: $type) {
                    ForEach(AccountType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }

                TextField("Plan Tier / Description:", text: $tierDescription)

                if type == .anthropicAPI {
                    SecureField("Anthropic API Key:", text: $secretKey, prompt: Text("sk-ant-api03-... or Admin Key"))
                    Text("API keys are saved in your macOS Keychain and used only for usage metrics.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if type == .claudeWeb {
                    SecureField("Claude.ai sessionKey:", text: $secretKey, prompt: Text("sk-ant-sid01-... from claude.ai cookie"))
                    Text("Found in browser DevTools > Application > Cookies > sessionKey.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if type == .rollingTracker {
                    Stepper("5-Hour Message Limit: \(rollingLimit)", value: $rollingLimit, in: 5...500, step: 5)
                    Text("Standard Claude Pro limit is ~45 messages every 5 hours.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Color picker row
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color Tag:")
                        .font(.system(size: 11, weight: .medium))

                    HStack(spacing: 10) {
                        ForEach(availableColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .shadow(radius: colorHex == hex ? 2 : 0)
                                .onTapGesture {
                                    colorHex = hex
                                }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let result = testResult {
                HStack {
                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(testSuccess ? .green : .red)
                    Text(result)
                        .font(.system(size: 11))
                        .foregroundColor(testSuccess ? .primary : .red)
                }
                .padding(8)
                .background((testSuccess ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(6)
            }

            HStack {
                if type != .rollingTracker && !secretKey.isEmpty {
                    Button(action: runConnectionTest) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTesting)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save Account") {
                    saveAndDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.claudeBrand)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            if let acc = account {
                if let savedSecret = AccountStore.shared.loadCredential(accountKey: acc.id.uuidString) {
                    secretKey = savedSecret
                }
            }
        }
    }

    private func runConnectionTest() {
        isTesting = true
        testResult = nil

        Task {
            if type == .anthropicAPI {
                do {
                    let result = try await AnthropicUsageService.shared.testConnection(apiKey: secretKey)
                    await MainActor.run {
                        self.testSuccess = result.isValid
                        self.testResult = result.message
                        self.isTesting = false
                    }
                } catch {
                    await MainActor.run {
                        self.testSuccess = false
                        self.testResult = "Error: \(error.localizedDescription)"
                        self.isTesting = false
                    }
                }
            } else if type == .claudeWeb {
                do {
                    let result = try await ClaudeWebService.shared.testConnection(sessionKey: secretKey)
                    await MainActor.run {
                        self.testSuccess = result.isValid
                        self.testResult = result.isValid ? "Connected to \(result.orgName ?? "Organization") (\(result.tierName ?? "Tier"))" : "Failed to validate session key"
                        if let tier = result.tierName {
                            self.tierDescription = tier
                        }
                        self.detectedOrgId = result.orgId
                        self.detectedOrgName = result.orgName
                        self.isTesting = false
                    }
                } catch {
                    await MainActor.run {
                        self.testSuccess = false
                        self.testResult = "Error: \(error.localizedDescription)"
                        self.isTesting = false
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        var updatedSnapshot = account?.snapshot ?? UsageSnapshot()
        updatedSnapshot.rollingLimit = rollingLimit

        let newAccount = ClaudeAccount(
            id: account?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            colorHex: colorHex,
            isPrimary: account?.isPrimary ?? false,
            tierDescription: tierDescription,
            organizationName: detectedOrgName ?? account?.organizationName,
            organizationId: detectedOrgId ?? account?.organizationId,
            lastSync: Date(),
            snapshot: updatedSnapshot
        )

        onSave(newAccount, secretKey.isEmpty ? nil : secretKey)
        dismiss()
    }
}
