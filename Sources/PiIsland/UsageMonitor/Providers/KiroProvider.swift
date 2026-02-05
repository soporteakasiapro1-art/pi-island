//
//  KiroProvider.swift
//  PiIsland
//
//  AWS Kiro usage provider (CLI-based)
//

import Foundation

actor KiroProvider: UsageProvider {
    let id: AIProvider = .kiro
    let displayName = "Kiro Plan"

    private let cliCommand = "kiro-cli"
    private let cliTimeout: TimeInterval = 15

    func hasCredentials() async -> Bool {
        // Check if kiro-cli is available
        return await cliExists()
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard await cliExists() else {
            return UsageSnapshot.error(.kiro, .noCLI(cliCommand))
        }

        do {
            let output = try await runKiroCli()
            return parseOutput(output)
        } catch {
            return UsageSnapshot.error(.kiro, .fetchFailed)
        }
    }

    private func cliExists() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [cliCommand]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func runKiroCli() async throws -> String {
        let process = Process()
        let pipe = Pipe()

        // Use shell to find the command in PATH
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "\(cliCommand) chat --no-interactive /usage"]
        process.standardOutput = pipe
        process.standardError = pipe

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["NO_COLOR"] = "1"
        process.environment = env

        try process.run()

        // Wait with timeout
        let deadline = Date().addingTimeInterval(cliTimeout)
        while process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        if process.isRunning {
            process.terminate()
            throw UsageError.timeout
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseOutput(_ output: String) -> UsageSnapshot {
        var windows: [RateWindow] = []

        // Parse credits percentage
        // Expected format: "Credits: 75% remaining" or "Credits: 25% used"
        if let creditsMatch = output.range(of: #"Credits?:?\s*(\d+(?:\.\d+)?)\s*%\s*(remaining|used|left)?"#, options: .regularExpression) {
            let match = String(output[creditsMatch])
            if let percentStr = match.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .first(where: { !$0.isEmpty }),
               let percent = Double(percentStr) {
                
                let isRemaining = match.lowercased().contains("remaining") || match.lowercased().contains("left")
                let usedPercent = isRemaining ? (100 - percent) : percent
                
                windows.append(RateWindow(
                    label: "Credits",
                    usedPercent: usedPercent
                ))
            }
        }

        // Parse reset date
        // Expected format: "Resets: March 1, 2025" or "Next reset: 2025-03-01"
        var resetAt: Date?
        if let resetMatch = output.range(of: #"(Resets?|Next reset):?\s*(.+)"#, options: .regularExpression) {
            let dateStr = String(output[resetMatch])
                .replacingOccurrences(of: #"(Resets?|Next reset):?\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            resetAt = parseDate(dateStr)
        }

        // Update first window with reset info if available
        if let reset = resetAt, !windows.isEmpty {
            let first = windows[0]
            windows[0] = RateWindow(
                label: first.label,
                usedPercent: first.usedPercent,
                resetDescription: formatRelativeTime(reset),
                resetAt: reset
            )
        }

        // If no specific parsing worked, try to detect general usage info
        if windows.isEmpty {
            // Look for any percentage
            if let percentMatch = output.range(of: #"(\d+(?:\.\d+)?)\s*%"#, options: .regularExpression) {
                let match = String(output[percentMatch])
                if let percentStr = match.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .first(where: { !$0.isEmpty }),
                   let percent = Double(percentStr) {
                    windows.append(RateWindow(
                        label: "Usage",
                        usedPercent: percent
                    ))
                }
            }
        }

        return UsageSnapshot(
            provider: .kiro,
            windows: windows
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd",
                "MMMM d, yyyy",
                "MMM d, yyyy",
                "MM/dd/yyyy"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US")
                return formatter
            }
        }()

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        // Try ISO8601
        return parseISO8601Date(string)
    }
}
