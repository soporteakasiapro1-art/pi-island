//
//  SyntheticProvider.swift
//  PiIsland
//
//  Synthetic usage provider
//

import Foundation

actor SyntheticProvider: UsageProvider {
    let id: AIProvider = .synthetic
    let displayName = "Synthetic"

    private let apiURL = URL(string: "https://api.synthetic.new/v2/quotas")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .synthetic)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .synthetic) else {
            return UsageSnapshot.error(.synthetic, .noCredentials)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.synthetic, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.synthetic, .fromHttpStatus(httpResponse.statusCode))
            }

            return try parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.synthetic, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.synthetic, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) throws -> UsageSnapshot {
        // Synthetic API format:
        // {
        //   "subscription": { "limit": 1350, "requests": 176.1, "renewsAt": "..." },
        //   "search": { "hourly": { "limit": 250, "requests": 0, "renewsAt": "..." } },
        //   "toolCallDiscounts": { "limit": 16200, "requests": 0, "renewsAt": "..." }
        // }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.synthetic, .fetchFailed)
        }
        
        #if DEBUG
        print("[Synthetic] Raw JSON: \(json)")
        #endif

        var windows: [RateWindow] = []

        // Parse subscription (main quota)
        if let subscription = json["subscription"] as? [String: Any] {
            if let window = parseQuotaBlock(subscription, label: "Subscription") {
                windows.append(window)
            }
        }

        // Parse search hourly quota
        if let search = json["search"] as? [String: Any],
           let hourly = search["hourly"] as? [String: Any] {
            if let window = parseQuotaBlock(hourly, label: "Search/hr") {
                windows.append(window)
            }
        }

        // Parse tool call discounts
        if let toolCalls = json["toolCallDiscounts"] as? [String: Any] {
            if let window = parseQuotaBlock(toolCalls, label: "Tool Calls") {
                windows.append(window)
            }
        }

        return UsageSnapshot(
            provider: .synthetic,
            windows: windows
        )
    }

    /// Parse a quota block with { limit, requests, renewsAt } format
    private func parseQuotaBlock(_ block: [String: Any], label: String) -> RateWindow? {
        guard let limit = block["limit"] as? Double, limit > 0 else { return nil }
        
        let requests = block["requests"] as? Double ?? 0
        let usedPercent = (requests / limit) * 100
        let resetAt = parseDate(block["renewsAt"])

        return RateWindow(
            label: label,
            usedPercent: usedPercent,
            resetDescription: formatReset(resetAt),
            usageDescription: "\(Int(requests)) / \(Int(limit))",
            resetAt: resetAt
        )
    }

    private func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }

        // Try ISO8601 first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }

        // Try common date formats
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
        ]

        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // Try unix timestamp
        if let timestamp = value as? Double ?? Double(string) {
            return Date(timeIntervalSince1970: timestamp)
        }

        return nil
    }

    private func formatReset(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
