//
//  DisplayMonitor.swift
//  PiIsland
//
//  Monitors display configuration changes to handle external monitors
//

@preconcurrency import AppKit
import Combine

/// Monitors display configuration changes and tracks the target screen for the notch
@MainActor
class DisplayMonitor: ObservableObject {
    /// The screen where the notch should appear (built-in if available, otherwise main)
    @Published private(set) var targetScreen: NSScreen?

    /// Whether the target screen has a physical notch
    @Published private(set) var hasPhysicalNotch: Bool = false

    private var observer: NSObjectProtocol?

    init() {
        updateTargetScreen()
        setupObserver()
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateTargetScreen()
            }
        }
    }

    func removeObserver() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func updateTargetScreen() {
        // Prefer built-in display (has the notch), fall back to main screen
        let newScreen = NSScreen.builtin ?? NSScreen.main
        let newHasNotch = newScreen?.hasPhysicalNotch ?? false

        // Only publish if changed
        if targetScreen != newScreen || hasPhysicalNotch != newHasNotch {
            targetScreen = newScreen
            hasPhysicalNotch = newHasNotch
        }
    }
}
