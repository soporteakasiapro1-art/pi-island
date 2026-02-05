//
//  UsageMenuView.swift
//  PiIsland
//
//  Menu view for displaying usage in status bar
//

import SwiftUI

struct UsageMenuView: View {
    @State private var service = UsageMonitorService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Usage Monitor")
                    .font(.headline)

                Spacer()

                if service.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Divider()

            // Provider list
            if service.snapshots.isEmpty {
                Text("No providers configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(service.snapshots.values.sorted(by: { $0.displayName < $1.displayName }))) { snapshot in
                    UsageRowView(snapshot: snapshot, compact: true)

                    if snapshot.id != service.snapshots.values.sorted(by: { $0.displayName < $1.displayName }).last?.id {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let lastUpdate = service.lastRefreshTime {
                    Text("Updated \(timeAgo(lastUpdate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    Task {
                        await service.refreshAll()
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct UsageMenuView_Previews: PreviewProvider {
    static var previews: some View {
        UsageMenuView()
    }
}
