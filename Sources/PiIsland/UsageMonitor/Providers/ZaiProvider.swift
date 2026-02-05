//
//  ZaiProvider.swift
//  PiIsland
//
//  z.ai usage provider
//

import Foundation

actor ZaiProvider: UsageProvider {
    let id: AIProvider = .zai
    let displayName = "z.ai Plan"

    private let apiURL = URL(string: "https://api.z.ai/api/monitor/usage/quota/limit")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .zai)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .zai) else {
            return UsageSnapshot.error(.zai, .noCredentials)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.zai, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.zai, .fromHttpStatus(httpResponse.statusCode))
            }

            return try parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.zai, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.zai, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.zai, .fetchFailed)
        }

        var windows: [RateWindow] = []

        // Parse token limits
        if let tokens = json["tokens"] as? [String: Any] {
            if let window = parseLimit(tokens, label: "Tokens") {
                windows.append(window)
            }
        }

        // Parse monthly limits
        if let monthly = json["monthly"] as? [String: Any] {
            if let window = parseLimit(monthly, label: "Month") {
                windows.append(window)
            }
        }

        // Parse daily limits
        if let daily = json["daily"] as? [String: Any] {
            if let window = parseLimit(daily, label: "Day") {
                windows.append(window)
            }
        }

        // Fallback: direct usage/limit at root level
        if windows.isEmpty {
            if let window = parseLimit(json, label: "Usage") {
                windows.append(window)
            }
        }

        // Alternative format: array of quotas
        if windows.isEmpty, let quotas = json["quotas"] as? [[String: Any]] {
            for quota in quotas {
                if let name = quota["name"] as? String ?? quota["type"] as? String,
                   let window = parseLimit(quota, label: name.capitalized) {
                    windows.append(window)
                }
            }
        }

        return UsageSnapshot(
            provider: .zai,
            windows: windows
        )
    }

    private func parseLimit(_ dict: [String: Any], label: String) -> RateWindow? {
        // Try used/limit format
        if let used = dict["used"] as? Double ?? dict["consumed"] as? Double,
           let limit = dict["limit"] as? Double ?? dict["total"] as? Double ?? dict["max"] as? Double,
           limit > 0 {
            let usedPercent = (used / limit) * 100
            let resetAt = parseISO8601Date(
                dict["resets_at"] as? String ??
                dict["reset_at"] as? String ??
                dict["resetTime"] as? String
            )
            return RateWindow(
                label: label,
                usedPercent: usedPercent,
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            )
        }

        // Try remaining format
        if let remaining = dict["remaining"] as? Double,
           let limit = dict["limit"] as? Double ?? dict["total"] as? Double,
           limit > 0 {
            let usedPercent = ((limit - remaining) / limit) * 100
            let resetAt = parseISO8601Date(
                dict["resets_at"] as? String ??
                dict["reset_at"] as? String
            )
            return RateWindow(
                label: label,
                usedPercent: usedPercent,
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            )
        }

        // Try percentage format
        if let percent = dict["percent_used"] as? Double ?? dict["utilization"] as? Double {
            let usedPercent = percent > 1 ? percent : percent * 100
            let resetAt = parseISO8601Date(dict["resets_at"] as? String)
            return RateWindow(
                label: label,
                usedPercent: usedPercent,
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            )
        }

        return nil
    }
}
