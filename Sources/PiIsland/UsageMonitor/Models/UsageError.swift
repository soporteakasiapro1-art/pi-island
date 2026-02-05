//
//  UsageError.swift
//  PiIsland
//
//  Error types for usage monitoring
//

import Foundation

/// Errors that can occur during usage fetching
enum UsageError: Error, Codable, Sendable, Equatable {
    case noCredentials
    case notLoggedIn
    case tokenExpired
    case noCLI(String)
    case fetchFailed
    case httpError(Int)
    case apiError(String)
    case timeout
    case unknown(String)

    /// Human-readable error message
    var message: String {
        switch self {
        case .noCredentials:
            return "No credentials found"
        case .notLoggedIn:
            return "Not logged in"
        case .tokenExpired:
            return "Token expired - run 'pi login'"
        case .noCLI(let cli):
            return "CLI not found: \(cli)"
        case .fetchFailed:
            return "Failed to fetch usage"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let msg):
            return "API error: \(msg)"
        case .timeout:
            return "Request timed out"
        case .unknown(let msg):
            return msg
        }
    }

    /// Short error code for display
    var code: String {
        switch self {
        case .noCredentials: return "NO_CREDS"
        case .notLoggedIn: return "NOT_LOGGED_IN"
        case .tokenExpired: return "EXPIRED"
        case .noCLI: return "NO_CLI"
        case .fetchFailed: return "FETCH_FAILED"
        case .httpError(let code): return "HTTP_\(code)"
        case .apiError: return "API_ERROR"
        case .timeout: return "TIMEOUT"
        case .unknown: return "UNKNOWN"
        }
    }

    /// Create error from HTTP status code
    static func fromHttpStatus(_ code: Int) -> UsageError {
        switch code {
        case 401: return .tokenExpired
        case 403: return .notLoggedIn
        default: return .httpError(code)
        }
    }
}
