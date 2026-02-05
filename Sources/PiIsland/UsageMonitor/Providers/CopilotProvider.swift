//
//  CopilotProvider.swift
//  PiIsland
//
//  GitHub Copilot usage provider
//

import Foundation

actor CopilotProvider: UsageProvider {
    let id: AIProvider = .copilot
    let displayName = "Copilot Plan"

    private let apiURL = URL(string: "https://api.github.com/copilot_internal/user")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .copilot)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .copilot) else {
            return UsageSnapshot.error(.copilot, .noCredentials)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.copilot, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.copilot, .fromHttpStatus(httpResponse.statusCode))
            }

            return parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.copilot, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.copilot, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.copilot, .fetchFailed)
        }

        var windows: [RateWindow] = []
        var requestsRemaining: Int?
        var requestsEntitlement: Int?

        // Parse reset date
        let resetDate = parseISO8601Date(json["quota_reset_date_utc"] as? String)
        let resetDesc = formatRelativeTime(resetDate)

        // Parse quota snapshots
        if let snapshots = json["quota_snapshots"] as? [String: Any],
           let premium = snapshots["premium_interactions"] as? [String: Any] {

            let percentRemaining = premium["percent_remaining"] as? Double ?? 100
            let monthUsedPercent = max(0, 100 - percentRemaining)

            windows.append(RateWindow(
                label: "Month",
                usedPercent: monthUsedPercent,
                resetDescription: resetDesc,
                resetAt: resetDate
            ))

            requestsRemaining = premium["remaining"] as? Int
            requestsEntitlement = premium["entitlement"] as? Int
        }

        return UsageSnapshot(
            provider: .copilot,
            windows: windows,
            requestsRemaining: requestsRemaining,
            requestsEntitlement: requestsEntitlement
        )
    }
}
