//
//  AnthropicProvider.swift
//  PiIsland
//
//  Anthropic/Claude usage provider
//

import Foundation

actor AnthropicProvider: UsageProvider {
    let id: AIProvider = .anthropic
    let displayName = "Claude Plan"

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .anthropic)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .anthropic) else {
            return UsageSnapshot.error(.anthropic, .noCredentials)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.anthropic, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.anthropic, .fromHttpStatus(httpResponse.statusCode))
            }

            return parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.anthropic, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.anthropic, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.anthropic, .fetchFailed)
        }

        var windows: [RateWindow] = []
        var extraUsageEnabled = false
        var fiveHourUsage: Double = 0

        // Parse 5-hour window
        // Note: Anthropic API returns utilization as percentage (0-100), not fraction (0-1)
        if let fiveHour = json["five_hour"] as? [String: Any],
           let utilization = fiveHour["utilization"] as? Double {
            fiveHourUsage = utilization  // Already a percentage
            let resetAt = parseISO8601Date(fiveHour["resets_at"] as? String)
            windows.append(RateWindow(
                label: "5h",
                usedPercent: fiveHourUsage,
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            ))
        }

        // Parse 7-day window
        if let sevenDay = json["seven_day"] as? [String: Any],
           let utilization = sevenDay["utilization"] as? Double {
            let resetAt = parseISO8601Date(sevenDay["resets_at"] as? String)
            windows.append(RateWindow(
                label: "Week",
                usedPercent: utilization,  // Already a percentage
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            ))
        }

        // Parse extra usage
        if let extra = json["extra_usage"] as? [String: Any],
           extra["is_enabled"] as? Bool == true {
            extraUsageEnabled = true

            let usedCredits = extra["used_credits"] as? Double ?? 0
            let monthlyLimit = extra["monthly_limit"] as? Double
            let utilization = extra["utilization"] as? Double ?? 0

            let extraStatus = fiveHourUsage >= 99 ? "active" : "on"
            let label: String
            if let limit = monthlyLimit, limit > 0 {
                label = "Extra [\(extraStatus)] $\(Int(usedCredits/100))/\(Int(limit/100))"
            } else {
                label = "Extra [\(extraStatus)] $\(Int(usedCredits/100))"
            }

            windows.append(RateWindow(
                label: label,
                usedPercent: utilization,  // Already a percentage
                resetDescription: extraStatus == "active" ? "ACTIVE" : nil
            ))
        }

        return UsageSnapshot(
            provider: .anthropic,
            windows: windows,
            extraUsageEnabled: extraUsageEnabled
        )
    }
}
