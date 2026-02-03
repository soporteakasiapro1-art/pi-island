//
//  NotchView.swift
//  PiIsland
//
//  The main dynamic island SwiftUI view
//

import SwiftUI
import ServiceManagement
import Combine

// Corner radius constants
private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

struct NotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isVisible: Bool = false
    @State private var isHovering: Bool = false
    @State private var shouldBounceLogo: Bool = false

    // MARK: - Sizing
    
    /// Extra width for expanding when there's activity (like Dynamic Island)
    private var expansionWidth: CGFloat {
        guard hasActivity else { return 0 }
        // Expand to make room for logo and indicator outside physical notch
        return 2 * sideWidth + 16
    }

    private var notchSize: CGSize {
        switch viewModel.status {
        case .closed:
            return CGSize(
                width: viewModel.closedNotchSize.width + expansionWidth,
                height: viewModel.closedNotchSize.height
            )
        case .hint:
            return CGSize(
                width: viewModel.closedNotchSize.width + expansionWidth,
                height: viewModel.closedNotchSize.height
            )
        case .opened:
            return viewModel.openedSize
        }
    }

    // MARK: - Corner Radii

    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    // Animation springs
    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    private let hintAnimation = Animation.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)

    private var animationForStatus: Animation {
        switch viewModel.status {
        case .opened:
            return openAnimation
        case .hint:
            return hintAnimation
        case .closed:
            return closeAnimation
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Outer container does NOT receive hits - only the notch content does
            VStack(spacing: 0) {
                notchLayout
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        alignment: .top
                    )
                    .padding(
                        .horizontal,
                        viewModel.status == .opened
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], viewModel.status == .opened ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .shadow(
                        color: (viewModel.status == .opened || isHovering) ? .black.opacity(0.7) : .clear,
                        radius: 6
                    )
                    .frame(
                        maxWidth: viewModel.status == .opened ? notchSize.width : nil,
                        maxHeight: viewModel.status == .opened ? notchSize.height : nil,
                        alignment: .top
                    )
                    .animation(animationForStatus, value: viewModel.status)
                    .animation(openAnimation, value: notchSize)
                    .animation(.smooth, value: hasActivity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                            isHovering = hovering
                        }
                    }
                    .onTapGesture {
                        if viewModel.status != .opened {
                            viewModel.notchOpen(reason: .click)
                        }
                    }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onAppear {
            // Always visible on non-notched devices
            if !viewModel.hasPhysicalNotch {
                isVisible = true
            }
            
            // Set up bounce animation callback
            viewModel.onAgentCompletedForBounce = { [self] in
                triggerBounceAnimation()
            }
        }
        .onChange(of: viewModel.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: viewModel.sessionManager.liveSessions) { _, sessions in
            handleSessionsChange(sessions)
        }
        // Reactive: No timer needed - @Observable drives updates automatically
    }

    // MARK: - Notch Layout

    @ViewBuilder
    private var notchLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row - always present, matches physical notch height
            headerRow
                .frame(height: max(24, viewModel.closedNotchSize.height))

            // Main content only when opened
            if viewModel.status == .opened {
                contentView
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.smooth(duration: 0.35)),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        )
                    )
            }
        }
    }

    // MARK: - Header Row

    /// Current activity state from SessionManager (reactive, no polling)
    private var activityState: SessionManager.ActivityState {
        viewModel.sessionManager.activityState
    }
    
    private var hasActivity: Bool {
        activityState != .idle
    }
    
    /// Color for activity state
    private func activityColor(for state: SessionManager.ActivityState) -> Color {
        switch state {
        case .idle: return .gray
        case .thinking: return .blue
        case .executing: return .cyan
        case .externallyActive: return .yellow
        case .error: return .red
        }
    }

    private var isHintState: Bool {
        viewModel.status == .hint
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            // Left side - Pi logo (always visible, animates when activity)
            HStack(spacing: 4) {
                PiLogo(
                    size: 14,
                    isAnimating: activityState.shouldAnimate,
                    isPulsing: isHintState,
                    bounce: shouldBounceLogo,
                    color: activityColor(for: activityState)
                )
            }
            .frame(width: viewModel.status == .opened ? nil : sideWidth)

            // Center content
            if viewModel.status == .opened {
                openedHeaderContent
            } else if !hasActivity {
                // Closed without activity: empty space
                Rectangle()
                    .fill(.clear)
                    .frame(width: viewModel.closedNotchSize.width - 20)
            } else {
                // Closed with activity: black spacer
                Rectangle()
                    .fill(.black)
                    .frame(width: viewModel.closedNotchSize.width - cornerRadiusInsets.closed.top)
            }

            // Right side - activity indicator (only when activity)
            if hasActivity {
                ActivityIndicator(state: activityState)
                    .frame(width: viewModel.status == .opened ? 20 : sideWidth)
            }
        }
        .frame(height: viewModel.closedNotchSize.height)
    }

    private var sideWidth: CGFloat {
        // Fixed width for side elements (logo and spinner)
        28
    }

    // MARK: - Opened Header Content

    @ViewBuilder
    private var openedHeaderContent: some View {
        HStack(spacing: 8) {
            // Left Side: Navigation (Back Button)
            if case .chat(let session) = viewModel.contentType {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.exitChat()
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Sessions")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Center: Spacer deals with the physical notch
                Spacer(minLength: 160)

                // Right Side: Model Selector
                if session.isLive {
                    ModelSelectorButton(session: session)
                } else if let model = session.model {
                     Text(model.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 6))
                }
            } else if case .sessions = viewModel.contentType {
                Spacer()

                // Settings button when showing sessions
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.showSettings()
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            } else {
                Spacer()
            }
        }
        .padding(.leading, 4)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        Group {
            switch viewModel.contentType {
            case .sessions:
                SessionsListView(viewModel: viewModel, sessionManager: viewModel.sessionManager)
            case .chat(let session):
                SessionChatView(session: session)
            case .settings:
                SettingsContentView(viewModel: viewModel)
            }
        }
        .frame(width: notchSize.width - 24) // Fixed width creates internal margins
    }

    // MARK: - Event Handlers

    private func handleStatusChange(from oldStatus: NotchStatus, to newStatus: NotchStatus) {
        switch newStatus {
        case .opened, .hint:
            isVisible = true
        case .closed:
            guard viewModel.hasPhysicalNotch else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if viewModel.status == .closed && !hasActivity && viewModel.unreadSession == nil {
                    isVisible = false
                }
            }
        }
    }

    private func handleSessionsChange(_ sessions: [ManagedSession]) {
        if sessions.contains(where: { $0.phase == .thinking || $0.phase == .executing }) {
            isVisible = true
        }
    }

    private func triggerBounceAnimation() {
        // Ensure visibility so user can see the bounce
        isVisible = true
        
        // Trigger bounce
        shouldBounceLogo = true
        
        // Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shouldBounceLogo = false
        }
    }
}

// MARK: - Activity Indicator (phase-specific)

struct ActivityIndicator: View {
    let state: SessionManager.ActivityState
    
    private var stateColor: Color {
        switch state {
        case .idle: return .gray
        case .thinking: return .blue
        case .executing: return .cyan
        case .externallyActive: return .yellow
        case .error: return .red
        }
    }
    
    var body: some View {
        switch state {
        case .thinking:
            // Brain/thinking icon
            Image(systemName: "brain")
                .font(.system(size: 12))
                .foregroundColor(stateColor)
        case .executing:
            // Tool/wrench icon
            Image(systemName: "wrench.fill")
                .font(.system(size: 11))
                .foregroundColor(stateColor)
        case .externallyActive:
            // Pulse dot
            PulseDot(color: stateColor)
        case .error:
            // Error indicator
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(stateColor)
        case .idle:
            EmptyView()
        }
    }
}

struct PulseDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Processing Spinner

struct ProcessingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - Sessions List View

// MARK: - Settings Content View

struct SettingsContentView: View {
    @ObservedObject var viewModel: NotchViewModel
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showInDock") private var showInDock = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { viewModel.exitSettings() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 12, weight: .medium)) // Increased from 11
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Settings")
                    .font(.system(size: 13, weight: .semibold)) // Increased from 12
                    .foregroundStyle(.white)

                Spacer()

                // Spacer for symmetry
                Color.clear.frame(width: 44)
            }

            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.top, 8)

            // Settings options
            VStack(spacing: 2) {
                SettingsToggleRow(
                    title: "Launch at Login",
                    subtitle: "Start Pi Island when you log in",
                    icon: "power",
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(enabled: newValue)
                }

                SettingsToggleRow(
                    title: "Show in Dock",
                    subtitle: "Display app icon in the Dock",
                    icon: "dock.rectangle",
                    isOn: $showInDock
                )
                .onChange(of: showInDock) { _, newValue in
                    setShowInDock(enabled: newValue)
                }
            }
            .padding(.vertical, 8)

            Spacer()

            // Update available banner
            if UpdateChecker.shared.updateAvailable, let version = UpdateChecker.shared.latestVersion {
                Button(action: { UpdateChecker.shared.openReleasePage() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Update Available")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                            Text("v\(version) - Click to download")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            // Version info
            Text("Pi Island v0.3.0")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    private func setShowInDock(enabled: Bool) {
        if enabled {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Settings Toggle Row

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Sessions List View

struct SessionsListView: View {
    @ObservedObject var viewModel: NotchViewModel
    @Bindable var sessionManager: SessionManager
    @State private var searchText = ""

    /// Filtered live sessions based on search
    private var filteredLiveSessions: [ManagedSession] {
        if searchText.isEmpty {
            return sessionManager.liveSessions
        }
        let query = searchText.lowercased()
        return sessionManager.liveSessions.filter {
            $0.projectName.lowercased().contains(query) ||
            $0.workingDirectory.lowercased().contains(query)
        }
    }

    /// Filtered historical sessions based on search
    private var filteredHistoricalSessions: [ManagedSession] {
        if searchText.isEmpty {
            return Array(sessionManager.historicalSessions.prefix(10))
        }
        let query = searchText.lowercased()
        return sessionManager.historicalSessions.filter {
            $0.projectName.lowercased().contains(query) ||
            $0.workingDirectory.lowercased().contains(query)
        }.prefix(20).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Sessions")
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

            // Normal scroll - sessions at top
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    // Live sessions first (at top)
                    ForEach(filteredLiveSessions) { session in
                        SessionRowView(
                            session: session,
                            isSelected: session.id == sessionManager.selectedSessionId,
                            onStop: {
                                stopSession(session)
                            }
                        )
                        .onTapGesture {
                            viewModel.showChat(for: session)
                        }
                    }

                    // Historical sessions
                    if !filteredHistoricalSessions.isEmpty {
                        Text(searchText.isEmpty ? "Recent" : "Results")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(filteredHistoricalSessions) { session in
                            SessionRowView(
                                session: session,
                                isSelected: false,
                                onDelete: {
                                    deleteSession(session)
                                }
                            )
                            .onTapGesture {
                                resumeHistoricalSession(session)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            // Refresh session list when view appears
            sessionManager.refreshSessions()
        }
    }

    private func showDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for the new Pi session"
        panel.prompt = "Select"
        
        // Run as a standalone window (not as sheet)
        panel.begin { response in
            if response == .OK, let url = panel.url {
                createNewSession(at: url)
            }
        }
    }

    private func createNewSession(at url: URL) {
        // Get security-scoped access
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access directory: \(url.path)")
            return
        }

        // Capture the path before releasing security scope
        let path = url.path
        
        // Release security scope - we only needed it to verify access
        // Pi will access the directory directly via its own process
        url.stopAccessingSecurityScopedResource()

        Task {
            let session = await sessionManager.createSession(workingDirectory: path)
            await MainActor.run {
                viewModel.showChat(for: session)
            }
        }
    }

    private func resumeHistoricalSession(_ session: ManagedSession) {
        // print("[DEBUG] resumeHistoricalSession: \(session.projectName), messages: \(session.messages.count)")

        // Immediately show the session (provides instant feedback)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.showChat(for: session)
        }

        // Resume in background - the session will update to live state
        Task {
            // print("[DEBUG] Starting resume task...")
            _ = await sessionManager.resumeSession(session)
            // print("[DEBUG] Resume complete: \(resumed?.projectName ?? "nil"), messages: \(resumed?.messages.count ?? 0)")
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

    var body: some View {
        HStack(spacing: 12) { // Increased spacing
            // Status indicator
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.projectName)
                    .font(.system(size: 13, weight: .medium)) // Increased from 11
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let model = session.model {
                    Text(model.name ?? model.id)
                        .font(.system(size: 11)) // Increased from 9
                        .foregroundStyle(.white.opacity(0.5))
                } else if !session.isLive {
                    Text(formatDate(session.lastActivity))
                        .font(.system(size: 11)) // Increased from 9
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
                .font(.system(size: 11)) // Increased from 10
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 12) // Increased padding
        .padding(.vertical, 10)   // Increased padding
        .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06)) // Slightly lighter backgrounds
        .clipShape(.rect(cornerRadius: 10)) // Smoother corners
    }

    private var phaseColor: Color {
        // Check for externally thinking sessions first (terminal pi)
        if session.isLikelyThinking {
            return .blue  // Thinking
        }

        // Check for externally active sessions
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

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
