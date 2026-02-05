//
//  UsageMonitorService.swift
//  PiIsland
//
//  Main service for monitoring AI provider usage
//

import Foundation
import Combine
import UserNotifications

/// Service for monitoring usage across all AI providers
@MainActor
@Observable
final class UsageMonitorService {
    // MARK: - Published State

    /// Current usage snapshots for all providers
    var snapshots: [AIProvider: UsageSnapshot] = [:]

    /// Whether a refresh is currently in progress
    var isRefreshing = false

    /// Last time usage was refreshed
    var lastRefreshTime: Date?

    /// Currently enabled providers
    var enabledProviders: Set<AIProvider> = Set(AIProvider.allCases)

    // MARK: - Configuration

    /// Refresh interval in seconds (default: 60)
    var refreshInterval: TimeInterval = 60

    /// Warning threshold for notifications (0-100)
    var warningThreshold: Double = 80

    /// Critical threshold for notifications (0-100)
    var criticalThreshold: Double = 95

    /// Enable/disable notifications
    var notificationsEnabled: Bool = true

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?
    private var timer: Timer?
    private var providers: [AIProvider: any UsageProvider] = [:]

    /// Track which providers have already triggered alerts to avoid spam
    private var warningAlertsSent: Set<AIProvider> = []
    private var criticalAlertsSent: Set<AIProvider> = []

    // MARK: - Initialization

    static let shared = UsageMonitorService()

    private init() {
        setupProviders()
        loadSettings()
        requestNotificationPermission()
    }

    private func setupProviders() {
        providers = [
            .anthropic: AnthropicProvider(),
            .copilot: CopilotProvider(),
            .synthetic: SyntheticProvider(),
            .geminiCli: GeminiCliProvider(),
            .antigravity: AntigravityProvider(),
            .codex: CodexProvider(),
            .kiro: KiroProvider(),
            .zai: ZaiProvider(),
        ]
    }

    private func loadSettings() {
        // Load from UserDefaults
        let defaults = UserDefaults.standard

        if let enabled = defaults.array(forKey: "usageMonitor.enabledProviders") as? [String] {
            enabledProviders = Set(enabled.compactMap { AIProvider(rawValue: $0) })
        }

        refreshInterval = defaults.double(forKey: "usageMonitor.refreshInterval")
        if refreshInterval == 0 { refreshInterval = 60 }

        warningThreshold = defaults.double(forKey: "usageMonitor.warningThreshold")
        if warningThreshold == 0 { warningThreshold = 80 }

        criticalThreshold = defaults.double(forKey: "usageMonitor.criticalThreshold")
        if criticalThreshold == 0 { criticalThreshold = 95 }

        notificationsEnabled = defaults.object(forKey: "usageMonitor.notificationsEnabled") as? Bool ?? true
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(Array(enabledProviders.map(\.rawValue)), forKey: "usageMonitor.enabledProviders")
        defaults.set(refreshInterval, forKey: "usageMonitor.refreshInterval")
        defaults.set(warningThreshold, forKey: "usageMonitor.warningThreshold")
        defaults.set(criticalThreshold, forKey: "usageMonitor.criticalThreshold")
        defaults.set(notificationsEnabled, forKey: "usageMonitor.notificationsEnabled")
    }

    private func requestNotificationPermission() {
        // Only request notification permission if we have a valid bundle identifier
        // (required for UNUserNotificationCenter to work)
        guard Bundle.main.bundleIdentifier != nil else { return }

        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            } catch {
                // Notifications not available - silently ignore
            }
        }
    }

    // MARK: - Public Methods

    /// Start monitoring with automatic refresh
    func startMonitoring() {
        stopMonitoring()

        // Immediate first refresh
        Task {
            await refreshAll()
        }

        // Setup timer for periodic refresh
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Refresh all enabled providers
    func refreshAll() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshTime = Date()
        }

        let oldSnapshots = snapshots

        await withTaskGroup(of: (AIProvider, UsageSnapshot).self) { group in
            for provider in enabledProviders {
                guard let usageProvider = providers[provider] else { continue }

                group.addTask {
                    let snapshot = await self.fetchWithTimeout(usageProvider)
                    return (provider, snapshot)
                }
            }

            for await (provider, snapshot) in group {
                snapshots[provider] = snapshot
            }
        }

        // Check for threshold crossings and send notifications
        if notificationsEnabled {
            checkThresholdsAndNotify(oldSnapshots: oldSnapshots)
        }
    }

    /// Refresh a specific provider
    func refresh(provider: AIProvider) async {
        guard let usageProvider = providers[provider] else { return }

        let snapshot = await fetchWithTimeout(usageProvider)
        snapshots[provider] = snapshot
    }

    /// Enable/disable a provider
    func setProviderEnabled(_ provider: AIProvider, enabled: Bool) {
        if enabled {
            enabledProviders.insert(provider)
        } else {
            enabledProviders.remove(provider)
        }
        saveSettings()
    }

    /// Check if a provider has credentials configured
    func hasCredentials(for provider: AIProvider) async -> Bool {
        guard let usageProvider = providers[provider] else { return false }
        return await usageProvider.hasCredentials()
    }

    /// Get aggregate status across all providers
    var overallStatus: UsageStatus {
        let statuses = snapshots.values.map(\.overallStatus)

        if statuses.contains(.critical) { return .critical }
        if statuses.contains(.caution) { return .caution }
        if statuses.contains(.warning) { return .warning }
        if statuses.contains(.error) { return .error }
        return .good
    }

    /// Whether any provider has data
    var hasData: Bool {
        !snapshots.isEmpty && snapshots.values.contains { !$0.windows.isEmpty }
    }

    /// Get only snapshots for providers that are properly configured
    /// (exclude NO_CREDS and NO_CLI errors)
    var configuredSnapshots: [UsageSnapshot] {
        snapshots.values
            .filter { snapshot in
                guard let error = snapshot.error else { return true }
                // Exclude providers that aren't configured
                switch error {
                case .noCredentials, .noCLI:
                    return false
                default:
                    return true
                }
            }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Private

    private func fetchWithTimeout(_ provider: any UsageProvider) async -> UsageSnapshot {
        do {
            return try await provider.fetchUsage()
        } catch {
            return UsageSnapshot.error(provider.id, .unknown(error.localizedDescription))
        }
    }

    // MARK: - Notifications

    private func checkThresholdsAndNotify(oldSnapshots: [AIProvider: UsageSnapshot]) {
        for (provider, snapshot) in snapshots {
            guard !snapshot.hasError else { continue }

            let maxUsage = snapshot.windows.map(\.usedPercent).max() ?? 0
            let oldMaxUsage = oldSnapshots[provider]?.windows.map(\.usedPercent).max() ?? 0

            // Check critical threshold
            if maxUsage >= criticalThreshold && oldMaxUsage < criticalThreshold {
                if !criticalAlertsSent.contains(provider) {
                    sendCriticalAlert(for: provider, usage: maxUsage)
                    criticalAlertsSent.insert(provider)
                }
            } else if maxUsage < criticalThreshold {
                criticalAlertsSent.remove(provider)
            }

            // Check warning threshold (only if not already critical)
            if maxUsage >= warningThreshold && maxUsage < criticalThreshold && oldMaxUsage < warningThreshold {
                if !warningAlertsSent.contains(provider) {
                    sendWarningAlert(for: provider, usage: maxUsage)
                    warningAlertsSent.insert(provider)
                }
            } else if maxUsage < warningThreshold {
                warningAlertsSent.remove(provider)
            }

            // Check for quota reset
            checkQuotaReset(provider: provider, snapshot: snapshot, oldSnapshot: oldSnapshots[provider])
        }
    }

    private func sendWarningAlert(for provider: AIProvider, usage: Double) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(provider.displayName) Usage Warning"
        content.body = "Usage is at \(Int(usage))%, approaching your limit."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage-warning-\(provider.rawValue)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sendCriticalAlert(for provider: AIProvider, usage: Double) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(provider.displayName) Usage Critical"
        content.body = "Usage is at \(Int(usage))%! You may hit your rate limit soon."
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: "usage-critical-\(provider.rawValue)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func checkQuotaReset(provider: AIProvider, snapshot: UsageSnapshot, oldSnapshot: UsageSnapshot?) {
        guard let oldSnapshot = oldSnapshot else { return }

        // Check if usage dropped significantly (likely a reset)
        for window in snapshot.windows {
            if let oldWindow = oldSnapshot.windows.first(where: { $0.label == window.label }) {
                // If usage dropped by more than 50%, it's likely a reset
                if oldWindow.usedPercent >= 50 && window.usedPercent < 10 {
                    sendQuotaResetNotification(for: provider, window: window.label)
                    // Clear alerts so they can fire again
                    warningAlertsSent.remove(provider)
                    criticalAlertsSent.remove(provider)
                }
            }
        }
    }

    private func sendQuotaResetNotification(for provider: AIProvider, window: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(provider.displayName) Quota Reset"
        content.body = "Your \(window) quota has been reset."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage-reset-\(provider.rawValue)-\(window)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Reset alert tracking (call when user acknowledges alerts)
    func resetAlertTracking() {
        warningAlertsSent.removeAll()
        criticalAlertsSent.removeAll()
    }
}
