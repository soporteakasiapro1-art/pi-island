//
//  SessionsListView.swift
//  PiIsland
//
//  Session list and row views displayed inside the notch
//

import SwiftUI

// MARK: - Sessions List View

struct SessionsListView: View {
    let viewModel: NotchViewModel
    @Bindable var sessionManager: SessionManager
    @State private var searchText = ""
    @State private var filteredLive: [ManagedSession] = []
    @State private var filteredHistorical: [ManagedSession] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Session Monitor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                // New session button
                Button(action: { showDirectoryPicker() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("New session")

                Text("\(sessionManager.liveSessions.count) active")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))

                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Divider()
                .background(Color.white.opacity(0.1))

            // Session list
            ScrollView(.vertical) {
                LazyVStack(spacing: 6) {
                    // Live sessions first (at top)
                    ForEach(filteredLive) { session in
                        Button {
                            viewModel.showChat(for: session)
                        } label: {
                            SessionRowView(
                                session: session,
                                isSelected: session.id == sessionManager.selectedSessionId,
                                onStop: { stopSession(session) }
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Historical sessions
                    if !filteredHistorical.isEmpty {
                        Text(searchText.isEmpty ? "Recent" : "Results")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(filteredHistorical) { session in
                            Button {
                                resumeHistoricalSession(session)
                            } label: {
                                SessionRowView(
                                    session: session,
                                    isSelected: false,
                                    onDelete: { deleteSession(session) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            sessionManager.refreshSessions()
            updateFilteredSessions()
        }
        .onChange(of: searchText) { _, _ in
            updateFilteredSessions()
        }
        .onChange(of: sessionManager.liveSessions) { _, _ in
            updateFilteredSessions()
        }
        .onChange(of: sessionManager.historicalSessions) { _, _ in
            updateFilteredSessions()
        }
    }

    // MARK: - Filtering

    private func updateFilteredSessions() {
        if searchText.isEmpty {
            filteredLive = sessionManager.liveSessions
            filteredHistorical = Array(sessionManager.historicalSessions.prefix(10))
        } else {
            filteredLive = sessionManager.liveSessions.filter {
                $0.projectName.localizedStandardContains(searchText) ||
                $0.workingDirectory.localizedStandardContains(searchText)
            }
            filteredHistorical = sessionManager.historicalSessions.filter {
                $0.projectName.localizedStandardContains(searchText) ||
                $0.workingDirectory.localizedStandardContains(searchText)
            }.prefix(20).map { $0 }
        }
    }

    // MARK: - Actions

    private func showDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for the new Pi session"
        panel.prompt = "Select"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                createNewSession(at: url)
            }
        }
    }

    private func createNewSession(at url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access directory: \(url.path)")
            return
        }

        let path = url.path
        url.stopAccessingSecurityScopedResource()

        Task {
            let session = await sessionManager.createSession(workingDirectory: path)
            await MainActor.run {
                viewModel.showChat(for: session)
            }
        }
    }

    private func resumeHistoricalSession(_ session: ManagedSession) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.showChat(for: session)
        }

        Task {
            _ = await sessionManager.resumeSession(session)
        }
    }

    private func stopSession(_ session: ManagedSession) {
        Task {
            await sessionManager.removeSession(session.id)
        }
    }

    private func deleteSession(_ session: ManagedSession) {
        Task {
            do {
                try await sessionManager.deleteSession(session.id)
            } catch {
                // Error already logged in SessionManager
            }
        }
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    @Bindable var session: ManagedSession
    let isSelected: Bool
    var onStop: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.projectName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let model = session.model {
                    Text(model.name ?? model.id)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                } else if !session.isLive {
                    Text(Self.relativeDateFormatter.localizedString(
                        for: session.lastActivity, relativeTo: Date()
                    ))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Stop button for live sessions
            if session.isLive, let onStop {
                Button(action: onStop) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Stop session")
            }

            // Delete button for historical sessions
            if !session.isLive, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var phaseColor: Color {
        if session.isLikelyThinking {
            return .blue
        }

        if session.isLikelyExternallyActive {
            return .yellow
        }

        switch session.phase {
        case .disconnected: return .gray
        case .starting: return .orange
        case .idle: return .green
        case .thinking: return .blue
        case .executing: return .cyan
        case .error: return .red
        }
    }
}
