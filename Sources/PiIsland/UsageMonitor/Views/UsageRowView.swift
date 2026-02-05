//
//  UsageRowView.swift
//  PiIsland
//
//  Single provider usage row
//

import SwiftUI

struct UsageRowView: View {
    let snapshot: UsageSnapshot
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            // Header
            HStack {
                Text(snapshot.displayName)
                    .font(compact ? .caption : .body)
                    .fontWeight(.medium)

                Spacer()

                if let error = snapshot.error {
                    Text(error.code)
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if let requests = snapshot.requestsSummary {
                    Text(requests)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Windows
            if snapshot.hasError {
                Text(snapshot.error?.message ?? "Unknown error")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if snapshot.windows.isEmpty {
                Text("No usage data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.windows, id: \.label) { window in
                    windowView(window)
                }
            }
        }
    }

    private func windowView(_ window: RateWindow) -> some View {
        HStack(spacing: 8) {
            // Label
            Text(window.label)
                .font(compact ? .caption2 : .caption)
                .foregroundColor(.secondary)
                .frame(width: compact ? 35 : 50, alignment: .leading)

            // Bar
            UsageBarView(percentage: window.usedPercent)
                .frame(maxWidth: .infinity)

            // Percentage
            Text("\(Int(window.usedPercent))%")
                .font(compact ? .caption2 : .caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)

            // Reset time (if available and not compact)
            if !compact, let reset = window.resetDescription {
                Text(reset)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

struct UsageRowView_Previews: PreviewProvider {
    static var previews: some View {
        let snapshot = UsageSnapshot(
            provider: .anthropic,
            windows: [
                RateWindow(label: "5h", usedPercent: 45, resetDescription: "in 2h"),
                RateWindow(label: "Week", usedPercent: 67, resetDescription: "in 2d")
            ],
            extraUsageEnabled: false
        )

        VStack {
            UsageRowView(snapshot: snapshot, compact: false)
            Divider()
            UsageRowView(snapshot: snapshot, compact: true)
        }
        .padding()
        .frame(width: 300)
    }
}
