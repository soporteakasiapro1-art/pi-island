//
//  SlashCommandParser.swift
//  PiIsland
//
//  Parses and handles slash commands like /help, /model, /thinking, /compact
//

import Foundation

/// Represents a parsed slash command or regular prompt
enum SlashCommand: Equatable {
    case help
    case model(String?)           // Optional model name filter
    case thinking(ThinkingLevel?) // Optional level, nil = cycle
    case compact
    case prompt(String)           // Regular message

    /// Parse input text into a command
    static func parse(_ input: String) -> SlashCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return .prompt(trimmed) }

        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        guard let cmd = parts.first?.lowercased() else { return .prompt(trimmed) }
        let arg = parts.count > 1 ? String(parts[1]) : nil

        switch cmd {
        case "help", "h", "?":
            return .help
        case "model", "m":
            return .model(arg)
        case "thinking", "t":
            if let a = arg, let level = ThinkingLevel(rawValue: a.lowercased()) {
                return .thinking(level)
            }
            return .thinking(nil) // Will cycle
        case "compact", "c":
            return .compact
        default:
            return .prompt(trimmed)
        }
    }

    /// Help text describing available commands
    static var helpText: String {
        """
        Available commands:
        /help           Show this help
        /model          Cycle to next model
        /model <name>   Switch to model containing <name>
        /thinking       Cycle thinking level
        /thinking <lv>  Set level (off/minimal/low/medium/high/xhigh)
        /compact        Compact context
        """
    }
}
