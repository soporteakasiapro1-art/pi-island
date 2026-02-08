//
//  RateWindow.swift
//  PiIsland
//
//  Rate limit window data structure
//

import Foundation

/// Represents a single rate limit window for an AI provider
struct RateWindow: Codable, Sendable, Equatable {
    /// Label for this window (e.g., "5h", "Week", "Month", "Pro")
    let label: String

    /// Usage percentage (0-100)
    let usedPercent: Double

    /// Human-readable reset description (e.g., "in 2h", "tomorrow")
    let resetDescription: String?

    /// Human-readable usage description (e.g., "150 / 2000")
    let usageDescription: String?

    /// ISO 8601 timestamp when the quota resets
    let resetAt: Date?

    init(
        label: String,
        usedPercent: Double,
        resetDescription: String? = nil,
        usageDescription: String? = nil,
        resetAt: Date? = nil
    ) {
        self.label = label
        self.usedPercent = max(0, min(100, usedPercent))
        self.resetDescription = resetDescription
        self.usageDescription = usageDescription
        self.resetAt = resetAt
    }

    /// Convenience computed property for remaining percentage
    var remainingPercent: Double {
        100 - usedPercent
    }

    /// Color indicator based on usage level
    var statusColor: UsageStatus {
        switch usedPercent {
        case 0..<50: return .good
        case 50..<80: return .warning
        case 80..<95: return .caution
        default: return .critical
        }
    }
}

/// Status levels for usage indicators
enum UsageStatus: Sendable {
    case good      // < 50%
    case warning   // 50-80%
    case caution   // 80-95%
    case critical  // >= 95%
    case error

    var color: String {
        switch self {
        case .good: return "32D74B"      // Green
        case .warning: return "FF9500"   // Orange
        case .caution: return "FFCC00"   // Yellow
        case .critical: return "FF3B30"  // Red
        case .error: return "8E8E93"     // Gray
        }
    }
}
