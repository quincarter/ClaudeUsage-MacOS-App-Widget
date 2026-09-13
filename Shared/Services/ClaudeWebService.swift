import Foundation

public struct ClaudeWebUsageData: Sendable {
    public let fiveHourPercent: Double?
    public let fiveHourResetsAt: Date?
    public let weeklyPercent: Double?
    public let weeklyResetsAt: Date?
    public let extraUsagePercent: Double?
    public let activeLimitKind: String?
    public let sevenDayBreakdown: [String: Double]?

    public init(
        fiveHourPercent: Double? = nil,
        fiveHourResetsAt: Date? = nil,
        weeklyPercent: Double? = nil,
        weeklyResetsAt: Date? = nil,
        extraUsagePercent: Double? = nil,
        activeLimitKind: String? = nil,
        sevenDayBreakdown: [String: Double]? = nil
    ) {
        self.fiveHourPercent = fiveHourPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.weeklyPercent = weeklyPercent
        self.weeklyResetsAt = weeklyResetsAt
        self.extraUsagePercent = extraUsagePercent
        self.activeLimitKind = activeLimitKind
        self.sevenDayBreakdown = sevenDayBreakdown
    }
}

public final class ClaudeWebService: Sendable {
    public static let shared = ClaudeWebService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Verifies sessionKey by calling the claude.ai organizations endpoint
    public func testConnection(sessionKey: String) async throws -> (isValid: Bool, orgName: String?, tierName: String?, orgId: String?) {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            return (false, nil, nil, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let cookieValue = sessionKey.hasPrefix("sessionKey=") ? sessionKey : "sessionKey=\(sessionKey)"
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return (false, nil, nil, nil)
        }

        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstOrg = jsonArray.first {
            let name = firstOrg["name"] as? String ?? "Claude Organization"
            let orgId = firstOrg["uuid"] as? String
            let capabilities = firstOrg["capabilities"] as? [String] ?? []
            let tier = capabilities.contains("claude_pro") ? "Claude Pro" : "Claude Free"
            return (true, name, tier, orgId)
        }

        return (false, nil, nil, nil)
    }

    /// Fetches live 5-hour rolling utilization and 7-day weekly caps directly from claude.ai
    public func fetchUsage(sessionKey: String, orgId: String? = nil) async throws -> (data: ClaudeWebUsageData, orgId: String, orgName: String?, tier: String) {
        let cookieValue = sessionKey.hasPrefix("sessionKey=") ? sessionKey : "sessionKey=\(sessionKey)"

        var targetOrgId = orgId
        var orgName: String?
        var tier = "Claude Pro"

        // If organization ID not yet resolved, fetch it first
        if targetOrgId == nil || targetOrgId?.isEmpty == true {
            let (valid, name, tierName, resolvedOrgId) = try await testConnection(sessionKey: sessionKey)
            guard valid, let resolved = resolvedOrgId else {
                throw NSError(domain: "ClaudeWebService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid session key or unable to retrieve organization"])
            }
            targetOrgId = resolved
            orgName = name
            if let t = tierName { tier = t }
        }

        guard let resolvedOrgId = targetOrgId,
              let usageURL = URL(string: "https://claude.ai/api/organizations/\(resolvedOrgId)/usage") else {
            throw NSError(domain: "ClaudeWebService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid usage endpoint URL"])
        }

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ClaudeWebService", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Usage request failed with status \(statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ClaudeWebService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to parse usage JSON"])
        }

        let parsedData = parseUsagePayload(json)
        return (parsedData, resolvedOrgId, orgName, tier)
    }

    /// Parses the Claude Web usage JSON payload
    private func parseUsagePayload(_ json: [String: Any]) -> ClaudeWebUsageData {
        // 1. Five Hour Window
        var fiveHourPercent: Double?
        var fiveHourResetsAt: Date?
        if let fh = json["five_hour"] as? [String: Any] {
            if let util = fh["utilization"] as? Double {
                fiveHourPercent = util
            } else if let utilInt = fh["utilization"] as? Int {
                fiveHourPercent = Double(utilInt)
            }
            if let resetsStr = fh["resets_at"] as? String {
                fiveHourResetsAt = parseISO8601(resetsStr)
            }
        }

        // 2. Seven Day (Weekly) Window
        var weeklyPercent: Double?
        var weeklyResetsAt: Date?
        if let sd = json["seven_day"] as? [String: Any] {
            if let util = sd["utilization"] as? Double {
                weeklyPercent = util
            } else if let utilInt = sd["utilization"] as? Int {
                weeklyPercent = Double(utilInt)
            }
            if let resetsStr = sd["resets_at"] as? String {
                weeklyResetsAt = parseISO8601(resetsStr)
            }
        }

        // 3. Extra Usage / Credits
        var extraUsagePercent: Double?
        if let extra = json["extra_usage"] as? [String: Any] {
            if let util = extra["utilization"] as? Double {
                extraUsagePercent = util
            } else if let utilInt = extra["utilization"] as? Int {
                extraUsagePercent = Double(utilInt)
            }
        }

        // 4. Active Limits
        var activeLimitKind: String?
        if let limits = json["limits"] as? [[String: Any]] {
            for limit in limits {
                let isActive = limit["is_active"] as? Bool ?? false
                let severity = limit["severity"] as? String ?? ""
                if isActive || severity == "critical" {
                    activeLimitKind = limit["kind"] as? String ?? limit["group"] as? String
                    if fiveHourResetsAt == nil, let resetStr = limit["resets_at"] as? String {
                        if activeLimitKind == "session" {
                            fiveHourResetsAt = parseISO8601(resetStr)
                        }
                    }
                    if weeklyResetsAt == nil, let resetStr = limit["resets_at"] as? String {
                        if activeLimitKind == "weekly" || activeLimitKind == "weekly_all" {
                            weeklyResetsAt = parseISO8601(resetStr)
                        }
                    }
                    break
                }
            }
        }

        // 5. Seven Day Breakdown
        var breakdown: [String: Double]?
        if let sdBreakdown = json["seven_day_breakdown"] as? [String: Any],
           let rows = sdBreakdown["rows"] as? [[String: Any]] {
            var map: [String: Double] = [:]
            for row in rows {
                if let name = row["display_name"] as? String ?? row["key"] as? String,
                   let pct = row["percent"] as? Double ?? (row["percent"] as? Int).map({ Double($0) }) {
                    map[name] = pct
                }
            }
            if !map.isEmpty {
                breakdown = map
            }
        }

        return ClaudeWebUsageData(
            fiveHourPercent: fiveHourPercent,
            fiveHourResetsAt: fiveHourResetsAt,
            weeklyPercent: weeklyPercent,
            weeklyResetsAt: weeklyResetsAt,
            extraUsagePercent: extraUsagePercent,
            activeLimitKind: activeLimitKind,
            sevenDayBreakdown: breakdown
        )
    }

    /// Reads local instance plan usage history from ~/.claude-instances/ as a fast, offline fallback
    public func fetchLocalInstanceUsage(accountName: String, orgId: String? = nil) -> ClaudeWebUsageData? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let instancesDir = homeDir.appendingPathComponent(".claude-instances", isDirectory: true)

        guard FileManager.default.fileExists(atPath: instancesDir.path) else {
            return nil
        }

        let candidates = [
            instancesDir.appendingPathComponent(accountName.lowercased()).appendingPathComponent("plan-usage-history.json"),
            instancesDir.appendingPathComponent(accountName).appendingPathComponent("plan-usage-history.json")
        ]

        var targetFile: URL? = candidates.first { FileManager.default.fileExists(atPath: $0.path) }

        // If not found directly by account name, scan all instances for matching orgId
        if targetFile == nil {
            if let contents = try? FileManager.default.contentsOfDirectory(at: instancesDir, includingPropertiesForKeys: nil) {
                for item in contents {
                    let historyFile = item.appendingPathComponent("plan-usage-history.json")
                    if FileManager.default.fileExists(atPath: historyFile.path) {
                        if let org = orgId, !org.isEmpty {
                            if let data = try? Data(contentsOf: historyFile),
                               let str = String(data: data, encoding: .utf8),
                               str.contains(org) {
                                targetFile = historyFile
                                break
                            }
                        } else if targetFile == nil {
                            targetFile = historyFile
                        }
                    }
                }
            }
        }

        guard let historyURL = targetFile,
              let data = try? Data(contentsOf: historyURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let samples = json["samples"] as? [[String: Any]],
              let lastSample = samples.last else {
            return nil
        }

        // Check if sample belongs to this org if orgId is known
        if let targetOrg = orgId, !targetOrg.isEmpty {
            if let matching = samples.last(where: { ($0["org"] as? String) == targetOrg }) {
                return parseSample(matching)
            }
        }

        return parseSample(lastSample)
    }

    private func parseSample(_ sample: [String: Any]) -> ClaudeWebUsageData? {
        guard let u = sample["u"] as? [String: Any] else { return nil }
        let fh = u["fh"] as? Double ?? (u["fh"] as? Int).map { Double($0) }
        let sd = u["sd"] as? Double ?? (u["sd"] as? Int).map { Double($0) }
        let xu = u["xu"] as? Double ?? (u["xu"] as? Int).map { Double($0) }

        return ClaudeWebUsageData(
            fiveHourPercent: fh,
            fiveHourResetsAt: nil,
            weeklyPercent: sd,
            weeklyResetsAt: nil,
            extraUsagePercent: xu,
            activeLimitKind: (fh ?? 0) >= 100 ? "session" : ((sd ?? 0) >= 95 ? "weekly" : nil),
            sevenDayBreakdown: nil
        )
    }

    private func parseISO8601(_ dateString: String) -> Date? {
        // Try ISO8601DateFormatter with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Fallback with DateFormatter
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        ]
        for pattern in patterns {
            df.dateFormat = pattern
            if let d = df.date(from: dateString) {
                return d
            }
        }
        return nil
    }
}
