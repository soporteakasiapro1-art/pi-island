//
//  AntigravityProvider.swift
//  PiIsland
//
//  Google Antigravity usage provider
//

import Foundation

actor AntigravityProvider: UsageProvider {
    let id: AIProvider = .antigravity
    let displayName = "Antigravity"

    private let endpoints = [
        "https://daily-cloudcode-pa.sandbox.googleapis.com",
        "https://cloudcode-pa.googleapis.com"
    ]
    private let apiTimeout: TimeInterval = 10

    // Models to hide from display
    private let hiddenModels: Set<String> = ["tab_flash_lite_preview"]

    func hasCredentials() async -> Bool {
        await CredentialManager.shared.hasCredentials(for: .antigravity)
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let token = await CredentialManager.shared.accessToken(for: .antigravity) else {
            return UsageSnapshot.error(.antigravity, .noCredentials)
        }

        var projectId = await CredentialManager.shared.credentialField("projectId", for: .antigravity)
        if projectId == nil {
            projectId = await CredentialManager.shared.credentialField("project", for: .antigravity)
        }

        // Try each endpoint
        let lastError: UsageError? = nil
        for endpoint in endpoints {
            if let result = try? await fetchFromEndpoint(endpoint, token: token, projectId: projectId) {
                return result
            }
        }

        return UsageSnapshot.error(.antigravity, lastError ?? .fetchFailed)
    }

    private func fetchFromEndpoint(
        _ endpoint: String,
        token: String,
        projectId: String?
    ) async throws -> UsageSnapshot? {
        let url = URL(string: "\(endpoint)/v1internal:fetchAvailableModels")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("antigravity/1.11.5 darwin/arm64", forHTTPHeaderField: "User-Agent")
        request.setValue("google-cloud-sdk vscode_cloudshelleditor/0.1", forHTTPHeaderField: "X-Goog-Api-Client")
        request.setValue(
            "{\"ideType\":\"IDE_UNSPECIFIED\",\"platform\":\"PLATFORM_UNSPECIFIED\",\"pluginType\":\"GEMINI\"}",
            forHTTPHeaderField: "Client-Metadata"
        )

        var body: [String: Any] = [:]
        if let projectId = projectId {
            body["project"] = projectId
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = apiTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        return try parseResponse(data)
    }

    private func parseResponse(_ data: Data) throws -> UsageSnapshot {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageSnapshot.error(.antigravity, .fetchFailed)
        }

        var windows: [RateWindow] = []

        // Parse models
        if let models = json["models"] as? [String: [String: Any]] {
            var modelQuotas: [String: ModelQuota] = [:]

            for (modelId, model) in models {
                // Skip hidden/internal models
                if hiddenModels.contains(modelId.lowercased()) { continue }
                if model["isInternal"] as? Bool == true { continue }

                let name = model["displayName"] as? String ?? modelId
                if hiddenModels.contains(name.lowercased()) { continue }

                // Get quota info - models without quotaInfo or remainingFraction are unlimited (treat as 100% remaining)
                let quotaInfo = model["quotaInfo"] as? [String: Any]
                let remainingFraction = quotaInfo?["remainingFraction"] as? Double ?? 1.0
                let resetTime = parseDate(quotaInfo?["resetTime"])

                // Keep the lowest (most used) fraction for each model name
                if let existing = modelQuotas[name] {
                    if remainingFraction < existing.remainingFraction {
                        modelQuotas[name] = ModelQuota(
                            name: name,
                            remainingFraction: remainingFraction,
                            resetAt: resetTime
                        )
                    } else if remainingFraction == existing.remainingFraction,
                              let newReset = resetTime,
                              let existingReset = existing.resetAt,
                              newReset < existingReset {
                        modelQuotas[name] = ModelQuota(
                            name: name,
                            remainingFraction: remainingFraction,
                            resetAt: newReset
                        )
                    }
                } else {
                    modelQuotas[name] = ModelQuota(
                        name: name,
                        remainingFraction: remainingFraction,
                        resetAt: resetTime
                    )
                }
            }

            // Create windows sorted by name
            for quota in modelQuotas.values.sorted(by: { $0.name < $1.name }) {
                windows.append(RateWindow(
                    label: quota.name,
                    usedPercent: (1 - quota.remainingFraction) * 100,
                    resetDescription: formatReset(quota.resetAt),
                    resetAt: quota.resetAt
                ))
            }
        }

        return UsageSnapshot(
            provider: .antigravity,
            windows: windows
        )
    }

    private func parseDate(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }

    private func formatReset(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private struct ModelQuota {
        let name: String
        let remainingFraction: Double
        let resetAt: Date?
    }
}
