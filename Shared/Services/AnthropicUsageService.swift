import Foundation

public final class AnthropicUsageService: Sendable {
    public static let shared = AnthropicUsageService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Verifies if an API key is valid by sending a lightweight models request
    public func testConnection(apiKey: String) async throws -> (isValid: Bool, message: String) {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return (false, "Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid server response")
        }

        if httpResponse.statusCode == 200 {
            return (true, "Connection successful! API key is active.")
        } else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            return (false, "Anthropic API returned error (\(httpResponse.statusCode)): \(errorText)")
        }
    }

    /// Attempts to fetch organization usage stats if the key has Admin permissions
    public func fetchUsageStats(adminKey: String) async throws -> (inputTokens: Int, outputTokens: Int, totalCost: Double)? {
        guard let url = URL(string: "https://api.anthropic.com/v1/organizations/usage") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let inputTokens = json["input_tokens"] as? Int ?? 0
            let outputTokens = json["output_tokens"] as? Int ?? 0
            let cost = json["total_cost_usd"] as? Double ?? 0.0
            return (inputTokens, outputTokens, cost)
        }

        return nil
    }
}
