//
//  GeminiCliProvider.swift
//  PiIsland
//
//  Google Gemini CLI usage provider
//

import Foundation

actor GeminiCliProvider: UsageProvider {
    let id: AIProvider = .geminiCli
    let displayName = "Gemini Plan"

    private let apiURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!
    private let apiTimeout: TimeInterval = 10

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .geminiCli)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .geminiCli) else {
            return UsageSnapshot.error(.geminiCli, .noCredentials)
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = apiTimeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return UsageSnapshot.error(.geminiCli, .fetchFailed)
            }

            guard httpResponse.statusCode == 200 else {
                return UsageSnapshot.error(.geminiCli, .fromHttpStatus(httpResponse.statusCode))
            }

            return try parseResponse(data)
        } catch is URLError {
            return UsageSnapshot.error(.geminiCli, .fetchFailed)
        } catch {
            return UsageSnapshot.error(.geminiCli, .unknown(error.localizedDescription))
        }
    }

    private func parseResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.geminiCli, .fetchFailed)
        }

        var windows: [RateWindow] = []
        var quotas: [String: Double] = [:]

        // Parse buckets
        if let buckets = json["buckets"] as? [[String: Any]] {
            for bucket in buckets {
                guard let model = bucket["modelId"] as? String else { continue }
                let fraction = bucket["remainingFraction"] as? Double ?? 1.0

                // Keep the lowest (most used) fraction for each model
                if let existing = quotas[model] {
                    quotas[model] = min(existing, fraction)
                } else {
                    quotas[model] = fraction
                }
            }
        }

        // Aggregate Pro models
        var proMin = 1.0
        var flashMin = 1.0
        var hasPro = false
        var hasFlash = false

        for (model, fraction) in quotas {
            let lowercased = model.lowercased()
            if lowercased.contains("pro") {
                hasPro = true
                proMin = min(proMin, fraction)
            }
            if lowercased.contains("flash") {
                hasFlash = true
                flashMin = min(flashMin, fraction)
            }
        }

        // Create windows for Pro and Flash
        if hasPro {
            windows.append(RateWindow(
                label: "Pro",
                usedPercent: (1 - proMin) * 100
            ))
        }

        if hasFlash {
            windows.append(RateWindow(
                label: "Flash",
                usedPercent: (1 - flashMin) * 100
            ))
        }

        // If no Pro/Flash found, show all models
        if windows.isEmpty {
            for (model, fraction) in quotas.sorted(by: { $0.key < $1.key }) {
                windows.append(RateWindow(
                    label: model,
                    usedPercent: (1 - fraction) * 100
                ))
            }
        }

        return UsageSnapshot(
            provider: .geminiCli,
            windows: windows
        )
    }
}
