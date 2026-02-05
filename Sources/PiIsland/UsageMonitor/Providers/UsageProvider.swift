//
//  UsageProvider.swift
//  PiIsland
//
//  Protocol for AI usage providers
//

import Foundation

/// Protocol for fetching usage data from AI service providers
protocol UsageProvider: Sendable {
    /// Provider identifier
    var id: AIProvider { get }

    /// Display name for the provider
    var displayName: String { get }

    /// Check if credentials are available for this provider
    func hasCredentials() async -> Bool

    /// Fetch current usage data
    /// - Returns: UsageSnapshot with rate windows and metadata
    func fetchUsage() async throws -> UsageSnapshot
}

// MARK: - Helper Functions

/// Default timeout for API calls
let defaultTimeout: TimeInterval = 10

/// Parse ISO8601 date string
func parseISO8601Date(_ string: String?) -> Date? {
    guard let string = string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
}

/// Format relative time for display
func formatRelativeTime(_ date: Date?) -> String? {
    guard let date = date else { return nil }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
