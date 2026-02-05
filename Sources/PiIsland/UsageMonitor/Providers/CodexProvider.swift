//
//  CodexProvider.swift
//  PiIsland
//
//  OpenAI Codex usage provider
//

import Foundation

actor CodexProvider: UsageProvider {
    let id: AIProvider = .codex
    let displayName = "Codex Plan"

    private let apiURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .codex)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .codex) else {
            return UsageSnapshot.error(.codex, .noCredentials)
        }

        let accountId = await CredentialManager.shared.credentialField("accountId", for: .codex)

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = accountId {
            request.setValue(accountId, forHTTPHeaderField: "X-Account-Id")
        }
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.codex, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.codex, .fromHttpStatus(httpResponse.statusCode))
            }

            return try parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.codex, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.codex, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.codex, .fetchFailed)
        }

        var windows: [RateWindow] = []

        // Parse primary rate window (short-term)
        if let primary = json["primary_rate_window"] as? [String: Any] {
            if let window = parseRateWindow(primary, label: "Primary") {
                windows.append(window)
            }
        }

        // Parse secondary rate window (longer-term)
        if let secondary = json["secondary_rate_window"] as? [String: Any] {
            if let window = parseRateWindow(secondary, label: "Secondary") {
                windows.append(window)
            }
        }

        // Fallback: try parsing as simple usage/limit format
        if windows.isEmpty {
            if let usage = json["usage"] as? Double,
               let limit = json["limit"] as? Double,
               limit > 0 {
                let usedPercent = (usage / limit) * 100
                let resetAt = parseISO8601Date(json["resets_at"] as? String)
                windows.append(RateWindow(
                    label: "Usage",
                    usedPercent: usedPercent,
                    resetDescription: formatRelativeTime(resetAt),
                    resetAt: resetAt
                ))
            }
        }

        return UsageSnapshot(
            provider: .codex,
            windows: windows
        )
    }

    private func parseRateWindow(_ dict: [String: Any], label: String) -> RateWindow? {
        // Try utilization first
        if let utilization = dict["utilization"] as? Double {
            let resetAt = parseISO8601Date(dict["resets_at"] as? String)
            return RateWindow(
                label: label,
                usedPercent: utilization * 100,
                resetDescription: formatRelativeTime(resetAt),
                resetAt: resetAt
            )
        }

        // Try used/limit format
        if let used = dict["used"] as? Double,
           let limit = dict["limit"] as? Double,
           limit > 0 {
            let usedPercent = (used / limit) * 100
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
