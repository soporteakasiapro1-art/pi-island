//
//  EventMonitors.swift
//  PiIsland
//
//  Global event monitors using Combine with battery-efficient filtering
//

import AppKit
import Combine

/// Shared global event monitors with battery-efficient mouse tracking
@MainActor
final class EventMonitors: Sendable {
    static let shared = EventMonitors()

    let mouseLocation = PassthroughSubject<CGPoint, Never>()
    let mouseDown = PassthroughSubject<Void, Never>()

    /// Region of interest for mouse tracking (notch area + margin)
    /// Set by NotchViewModel based on current notch geometry
    var trackingRegion: CGRect = .zero

    /// Whether detailed tracking is needed (notch is open or animating)
    var needsDetailedTracking: Bool = false

    /// Margin around tracking region to start tracking before entering
    private let trackingMargin: CGFloat = 100

    private init() {
        setupMonitors()
    }

    private func setupMonitors() {
        // Global mouse moved - filter by region for battery efficiency
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let location = NSEvent.mouseLocation

                // Always track if detailed tracking is needed (notch open/animating)
                // Otherwise only track if mouse is near the tracking region
                if self.needsDetailedTracking || self.isNearTrackingRegion(location) {
                    self.mouseLocation.send(location)
                }
            }
        }

        // Local mouse moved (within app) - always track
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in
                self?.mouseLocation.send(NSEvent.mouseLocation)
            }
            return event
        }

        // Global mouse down
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.mouseDown.send()
            }
        }

        // Local mouse down
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.mouseDown.send()
            }
            return event
        }
    }

    /// Check if location is near the tracking region (with margin)
    private func isNearTrackingRegion(_ location: CGPoint) -> Bool {
        guard trackingRegion != .zero else { return true } // Track everything if no region set

        let expandedRegion = trackingRegion.insetBy(dx: -trackingMargin, dy: -trackingMargin)
        return expandedRegion.contains(location)
    }

    /// Update the tracking region based on notch geometry
    func updateTrackingRegion(notchFrame: CGRect, openedFrame: CGRect?) {
        if let opened = openedFrame {
            // When open, track the larger opened area
            trackingRegion = opened.union(notchFrame)
        } else {
            // When closed, just track around the notch
            trackingRegion = notchFrame
        }
    }
}
