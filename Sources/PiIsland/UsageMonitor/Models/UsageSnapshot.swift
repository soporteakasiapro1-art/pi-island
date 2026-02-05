//
//  UsageSnapshot.swift
//  PiIsland
//
//  Usage data snapshot for an AI provider
//

import Foundation

/// Complete usage snapshot for a provider
struct UsageSnapshot: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let provider: AIProvider
    let displayName: String
    let windows: [RateWindow]
    let lastUpdated: Date
    let error: UsageError?

    // Provider-specific extras
    let extraUsageEnabled: Bool?      // Anthropic
    let requestsRemaining: Int?       // Copilot
    let requestsEntitlement: Int?     // Copilot

    init(
        provider: AIProvider,
        windows: [RateWindow],
        error: UsageError? = nil,
        extraUsageEnabled: Bool? = nil,
        requestsRemaining: Int? = nil,
        requestsEntitlement: Int? = nil
    ) {
        self.id = provider.rawValue
        self.provider = provider
        self.displayName = provider.displayName
        self.windows = windows
        self.lastUpdated = Date()
        self.error = error
        self.extraUsageEnabled = extraUsageEnabled
        self.requestsRemaining = requestsRemaining
        self.requestsEntitlement = requestsEntitlement
    }

    /// Create an error snapshot
    static func error(_ provider: AIProvider, _ error: UsageError) -> UsageSnapshot {
        UsageSnapshot(provider: provider, windows: [], error: error)
    }

    /// Whether this snapshot represents an error state
    var hasError: Bool {
        error != nil
    }

    /// Summary string for menu display
    var summary: String {
        if let error = error {
            return "Error: \(error.message)"
        }

        if windows.isEmpty {
            return "No usage data"
        }

        // Return the most relevant window's info
        if let first = windows.first {
            return "\(first.label): \(Int(first.usedPercent))%"
        }

        return "OK"
    }

    /// Aggregate status across all windows
    var overallStatus: UsageStatus {
        if hasError {
            return .error
        }

        let maxUsage = windows.map(\.usedPercent).max() ?? 0
        switch maxUsage {
        case 0..<50: return .good
        case 50..<80: return .warning
        case 80..<95: return .caution
        default: return .critical
        }
    }

    /// Formatted requests string for providers that support it
    var requestsSummary: String? {
        guard let remaining = requestsRemaining,
              let entitlement = requestsEntitlement,
              entitlement > 0 else {
            return nil
        }
        return "\(remaining)/\(entitlement)"
    }
}
