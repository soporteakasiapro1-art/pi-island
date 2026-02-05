//
//  AIProvider.swift
//  PiIsland
//
//  AI Provider enumeration for usage monitoring
//

import Foundation

/// Supported AI service providers for usage monitoring
enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case anthropic
    case copilot = "github-copilot"
    case synthetic
    case geminiCli = "google-gemini-cli"
    case antigravity = "google-antigravity"
    case codex = "openai-codex"
    case kiro
    case zai

    var id: String { rawValue }

    /// Display name for the provider
    var displayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .copilot: return "GitHub Copilot"
        case .synthetic: return "Synthetic"
        case .geminiCli: return "Gemini CLI"
        case .antigravity: return "Antigravity"
        case .codex: return "OpenAI Codex"
        case .kiro: return "AWS Kiro"
        case .zai: return "z.ai"
        }
    }

    /// Icon/system image name (if available)
    var iconName: String? {
        switch self {
        case .anthropic: return "bubble.left.fill"
        case .copilot: return "copilot"
        case .synthetic: return "cpu"
        case .geminiCli: return "sparkles"
        case .antigravity: return "ant"
        case .codex: return "terminal"
        case .kiro: return "cloud"
        case .zai: return "z.circle"
        }
    }

    /// Whether this provider requires CLI tool vs API key
    var requiresCLI: Bool {
        switch self {
        case .kiro: return true
        default: return false
        }
    }

    /// Auth key used in pi's auth.json
    var authKey: String {
        switch self {
        case .anthropic: return "anthropic"
        case .copilot: return "github-copilot"
        case .synthetic: return "synthetic"
        case .geminiCli: return "google-gemini-cli"
        case .antigravity: return "google-antigravity"
        case .codex: return "openai-codex"
        case .kiro: return "kiro"
        case .zai: return "z-ai"
        }
    }
}
