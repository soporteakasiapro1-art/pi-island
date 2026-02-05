//
//  UsageSettingsView.swift
//  PiIsland
//
//  Settings view for usage monitoring
//

import SwiftUI

struct UsageSettingsView: View {
    @State private var service = UsageMonitorService.shared
    @State private var credentialStatus: [AIProvider: Bool] = [:]

    var body: some View {
        Form {
            Section(header: Text("Providers")) {
                ForEach(AIProvider.allCases) { provider in
                    ProviderToggleRow(
                        provider: provider,
                        isEnabled: service.enabledProviders.contains(provider),
                        hasCredentials: credentialStatus[provider] ?? false,
                        onToggle: { enabled in
                            service.setProviderEnabled(provider, enabled: enabled)
                        }
                    )
                }
            }

            Section(header: Text("Refresh")) {
                HStack {
                    Text("Interval")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { Int(service.refreshInterval) },
                        set: { service.refreshInterval = TimeInterval($0) }
                    )) {
                        Text("30s").tag(30)
                        Text("1m").tag(60)
                        Text("5m").tag(300)
                        Text("15m").tag(900)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                HStack {
                    Spacer()
                    Button("Refresh Now") {
                        Task {
                            await service.refreshAll()
                        }
                    }
                    .disabled(service.isRefreshing)
                    Spacer()
                }
            }

            Section(header: Text("Notifications")) {
                Toggle("Enable Notifications", isOn: Binding(
                    get: { service.notificationsEnabled },
                    set: { service.notificationsEnabled = $0 }
                ))

                VStack(alignment: .leading) {
                    Text("Warning at \(Int(service.warningThreshold))%")
                    Slider(value: $service.warningThreshold, in: 50...90, step: 5)
                }
                .disabled(!service.notificationsEnabled)

                VStack(alignment: .leading) {
                    Text("Critical at \(Int(service.criticalThreshold))%")
                    Slider(value: $service.criticalThreshold, in: 80...99, step: 1)
                }
                .disabled(!service.notificationsEnabled)
            }

            Section {
                NavigationLink("View Usage") {
                    UsageDetailView()
                }
            }
        }
        .navigationTitle("Usage Monitor")
        .task {
            await checkCredentials()
        }
    }

    private func checkCredentials() async {
        for provider in AIProvider.allCases {
            let hasCreds = await service.hasCredentials(for: provider)
            credentialStatus[provider] = hasCreds
        }
    }
}

struct ProviderToggleRow: View {
    let provider: AIProvider
    let isEnabled: Bool
    let hasCredentials: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: provider.iconName ?? "cpu")
                .foregroundColor(hasCredentials ? .primary : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.body)

                if !hasCredentials {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in onToggle(newValue) }
            ))
            .disabled(!hasCredentials)
        }
        .padding(.vertical, 4)
    }
}

struct UsageDetailView: View {
    @State private var service = UsageMonitorService.shared

    var body: some View {
        List {
            ForEach(Array(service.snapshots.values.sorted(by: { $0.displayName < $1.displayName }))) { snapshot in
                Section(header: Text(snapshot.displayName)) {
                    UsageRowView(snapshot: snapshot, compact: false)
                }
            }

            if service.snapshots.isEmpty {
                Section {
                    Text("No usage data available. Enable providers in settings.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Usage Details")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    Task { await service.refreshAll() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(service.isRefreshing)
            }
        }
    }
}

struct UsageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UsageSettingsView()
        }
    }
}
