//
//  UpdateChecker.swift
//  PiIsland
//
//  Checks GitHub releases for updates
//

import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.pi-island", category: "UpdateChecker")

@MainActor
@Observable
class UpdateChecker {
    static let shared = UpdateChecker()
    
    private let repoOwner = "jwintz"
    private let repoName = "pi-island"
    
    var updateAvailable: Bool = false
    var latestVersion: String?
    var releaseURL: URL?
    var releaseNotes: String?
    
    private var lastCheckDate: Date?
    private let checkInterval: TimeInterval = 3600 // Check at most once per hour
    
    private init() {}
    
    /// Check for updates (rate-limited to once per hour)
    func checkForUpdates(force: Bool = false) async {
        // Rate limit checks unless forced
        if !force, let lastCheck = lastCheckDate, Date().timeIntervalSince(lastCheck) < checkInterval {
            return
        }
        
        lastCheckDate = Date()
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Pi-Island/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.warning("GitHub API returned non-200 status")
                return
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            // Extract version from tag (remove 'v' prefix if present)
            let tagVersion = release.tagName.hasPrefix("v") 
                ? String(release.tagName.dropFirst()) 
                : release.tagName
            
            latestVersion = tagVersion
            releaseURL = URL(string: release.htmlURL)
            releaseNotes = release.body
            
            // Compare versions
            updateAvailable = isNewerVersion(tagVersion, than: AppVersion.current)
            
            if updateAvailable {
                logger.info("Update available: \(tagVersion) (current: \(AppVersion.current))")
            } else {
                logger.debug("No update available (latest: \(tagVersion), current: \(AppVersion.current))")
            }
            
        } catch {
            logger.error("Failed to check for updates: \(error.localizedDescription)")
        }
    }
    
    /// Open the release page in browser
    func openReleasePage() {
        guard let url = releaseURL else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// Compare semantic versions (simple implementation)
    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            
            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        
        return false
    }
}

// MARK: - GitHub API Types

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}
