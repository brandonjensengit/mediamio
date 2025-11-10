//
//  VideoPlayerView.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 5: Netflix-Style Video Player
//

import SwiftUI
import AVKit
import MediaPlayer
import Combine

// MARK: - AVPlayerViewController Wrapper

struct CustomVideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let viewModel: VideoPlayerViewModel
    let onClose: () -> Void
    @Binding var showSubtitlePicker: Bool
    @Binding var showBitratePicker: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎥 CustomVideoPlayerController.makeUIViewController()")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // Hide default controls

        // Disable AVPlayerViewController's remote command handling
        controller.requiresLinearPlayback = false

        // CRITICAL: Create UIKit overlay for proper focus navigation
        let overlayVC = VideoOverlayViewController()
        overlayVC.viewModel = viewModel
        overlayVC.onClose = onClose
        overlayVC.onShowSubtitlePicker = {
            showSubtitlePicker = true
        }
        overlayVC.onShowBitratePicker = {
            showBitratePicker = true
        }

        // Set as customOverlayViewController (NOT contentOverlayView!)
        controller.customOverlayViewController = overlayVC
        context.coordinator.overlayViewController = overlayVC

        // Diagnostic: Check player state
        print("📊 Player status: \(player.status.rawValue)")
        print("📊 Player rate: \(player.rate)")
        if let item = player.currentItem {
            print("📊 Player item status: \(item.status.rawValue)")
            print("📊 Player item duration: \(item.duration.seconds)s")
            print("📊 Player item tracks: \(item.tracks.count)")
            print("📊 Player item presentation size: \(item.presentationSize)")

            // Check for video tracks
            let videoTracks = item.tracks.filter { track in
                if let assetTrack = track.assetTrack {
                    return assetTrack.mediaType == .video
                }
                return false
            }
            print("📊 Video tracks in player: \(videoTracks.count)")
            if videoTracks.isEmpty {
                print("❌ NO VIDEO TRACKS - This is why there's no video!")
            }
        } else {
            print("⚠️ No player item!")
        }

        print("✅ AVPlayerViewController created with custom overlay")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        print("🔄 CustomVideoPlayerController.updateUIViewController() - isPlaying: \(viewModel.isPlaying)")

        // Update player if changed
        if uiViewController.player !== player {
            print("   Player changed, updating")
            uiViewController.player = player
        }

        // Update overlay with latest data
        context.coordinator.overlayViewController?.updateFromViewModel()

        // Show overlay (it will handle auto-hide based on play state)
        context.coordinator.overlayViewController?.show()

        print("   ✅ Update complete")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var overlayViewController: VideoOverlayViewController?
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let item: MediaItem
    let authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel: VideoPlayerViewModel
    @StateObject private var settingsManager = SettingsManager()
    @State private var showSubtitlePicker = false
    @State private var showBitratePicker = false

    init(item: MediaItem, authService: AuthenticationService) {
        self.item = item
        self.authService = authService

        // Initialize ViewModel
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            item: item,
            authService: authService
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // AVPlayerViewController with UIKit overlay (for proper focus navigation)
            if let player = viewModel.player {
                CustomVideoPlayerController(
                    player: player,
                    viewModel: viewModel,
                    onClose: {
                        navigationManager.closePlayer()
                    },
                    showSubtitlePicker: $showSubtitlePicker,
                    showBitratePicker: $showBitratePicker
                )
                .ignoresSafeArea()
                .onAppear {
                    viewModel.startPlayback()
                }
                .onDisappear {
                    viewModel.pausePlayback()
                }
            } else if viewModel.isLoading {
                LoadingView(message: "Loading video...", showLogo: false)
            } else if let error = viewModel.errorMessage {
                ErrorPlayerView(message: error) {
                    Task {
                        await viewModel.loadVideoURL()
                    }
                }
            }

            // Debug Stats Overlay (top-right corner, always visible)
            // TODO: Enable with a settings toggle
            // DebugStatsOverlay(stats: viewModel.debugStats)
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showBitratePicker) {
            BitratePickerModal(settingsManager: settingsManager)
        }
        .onPlayPauseCommand {
            print("🎮 Play/Pause command received!")
            viewModel.togglePlayPause()
        }
        .task {
            await viewModel.loadVideoURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.pausePlayback()
        }
        .onDisappear {
            // Clean up when leaving the player
            viewModel.cleanup()
        }
    }
}

// MARK: - Remote Command Coordinator

@MainActor
class RemoteCommandCoordinator: ObservableObject {
    @Published var showControls: Bool = true
    private var commandTargets: [Any] = [] // Store targets so they don't get deallocated

    func setupRemoteCommands(viewModel: VideoPlayerViewModel, onShowControls: @escaping () -> Void) {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Clear old targets
        removeRemoteCommands()

        print("🎮 Setting up remote commands...")

        // Configure audio session to enable remote controls
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for remote control")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }

        // Play command
        commandCenter.playCommand.isEnabled = true
        let playTarget = commandCenter.playCommand.addTarget { [weak viewModel] _ in
            print("🎮 Remote: Play command received!")
            Task { @MainActor in
                viewModel?.startPlayback()
                onShowControls()
            }
            return .success
        }
        commandTargets.append(playTarget)

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        let pauseTarget = commandCenter.pauseCommand.addTarget { [weak viewModel] _ in
            print("🎮 Remote: Pause command received!")
            Task { @MainActor in
                viewModel?.pausePlayback()
                onShowControls()
            }
            return .success
        }
        commandTargets.append(pauseTarget)

        // Toggle play/pause command - THIS is what tvOS remote actually sends
        commandCenter.togglePlayPauseCommand.isEnabled = true
        let toggleTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak viewModel] _ in
            print("🎮 Remote: Toggle play/pause received!")
            Task { @MainActor in
                viewModel?.togglePlayPause()
                onShowControls()
            }
            return .success
        }
        commandTargets.append(toggleTarget)

        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        let forwardTarget = commandCenter.skipForwardCommand.addTarget { [weak viewModel] _ in
            print("🎮 Remote: Skip forward received!")
            Task { @MainActor in
                viewModel?.seekForward()
                onShowControls()
            }
            return .success
        }
        commandTargets.append(forwardTarget)

        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        let backwardTarget = commandCenter.skipBackwardCommand.addTarget { [weak viewModel] _ in
            print("🎮 Remote: Skip backward received!")
            Task { @MainActor in
                viewModel?.seekBackward()
                onShowControls()
            }
            return .success
        }
        commandTargets.append(backwardTarget)

        print("✅ Remote commands registered: \(commandTargets.count) targets")
        print("   - Play, Pause, Toggle, Skip Forward, Skip Backward")
        print("   - Waiting for remote button presses...")
    }

    func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        // Remove all stored targets
        for target in commandTargets {
            commandCenter.playCommand.removeTarget(target)
            commandCenter.pauseCommand.removeTarget(target)
            commandCenter.togglePlayPauseCommand.removeTarget(target)
            commandCenter.skipForwardCommand.removeTarget(target)
            commandCenter.skipBackwardCommand.removeTarget(target)
        }
        commandTargets.removeAll()

        print("🎮 Remote commands disabled")
    }
}

// MARK: - Player Controls Overlay

struct PlayerControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let onClose: () -> Void

    @StateObject private var coordinator = RemoteCommandCoordinator()
    @State private var hideTimer: Timer?
    @State private var hideTask: Task<Void, Never>?
    @State private var pauseShowTask: Task<Void, Never>?
    @State private var lastSeekTime: Double = 0
    @State private var showSubtitlePicker = false
    @State private var showBitratePicker = false
    @StateObject private var settingsManager = SettingsManager()
    @FocusState private var focusedControl: PlayerControl?

    private var showControls: Binding<Bool> {
        $coordinator.showControls
    }

    enum PlayerControl {
        case playPause
        case seekBackward
        case seekForward
        case subtitle
        case bitrate
        case audio
        case close
    }

    // Computed property for quality badge
    private var qualityBadgeText: String {
        // Get quality from SettingsManager
        let settingsManager = SettingsManager()
        let quality = VideoQuality(rawValue: settingsManager.videoQuality) ?? .auto

        switch quality {
        case .auto:
            return "AUTO"
        case .uhd4K:
            return "4K"
        case .fullHD:
            return "1080p"
        case .hd:
            return "720p"
        case .sd:
            return "480p"
        }
    }

    var body: some View {
        ZStack {
            // Controls are ALWAYS present, just opacity changes
            VStack {
                // Top Bar with Metadata
                HStack(alignment: .top) {
                    // Title and Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(viewModel.item.name)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Episode Info for TV Shows
                        if let seriesName = viewModel.item.seriesName,
                           let seasonNum = viewModel.item.parentIndexNumber,
                           let episodeNum = viewModel.item.indexNumber {
                            Text("\(seriesName) · S\(seasonNum):E\(episodeNum)")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // Metadata Badges
                        HStack(spacing: 12) {
                            // Year
                            if let year = viewModel.item.yearText {
                                MetadataBadge(text: year, icon: nil)
                            }

                            // Rating
                            if let rating = viewModel.item.ratingText {
                                MetadataBadge(text: rating, icon: "star.fill")
                            }

                            // Duration
                            if let duration = viewModel.item.runtimeFormatted {
                                MetadataBadge(text: duration, icon: "clock")
                            }

                            // Official Rating
                            if let officialRating = viewModel.item.officialRating {
                                MetadataBadge(text: officialRating, icon: nil, style: .outlined)
                            }

                            // Quality Badge
                            MetadataBadge(text: qualityBadgeText, icon: nil, style: .outlined)
                        }
                    }

                    Spacer()

                    // Close Button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focused($focusedControl, equals: .close)
                }
                .padding(.horizontal, 60)
                .padding(.top, 60)

                Spacer()

                // Center Controls
                HStack(spacing: 60) {
                    // Seek Backward
                    PlayerControlButton(
                        icon: "gobackward.10",
                        size: 60
                    ) {
                        viewModel.seekBackward()
                        resetHideTimer()
                    }
                    .focused($focusedControl, equals: .seekBackward)

                    // Play/Pause
                    PlayerControlButton(
                        icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                        size: 80
                    ) {
                        viewModel.togglePlayPause()
                        resetHideTimer()
                    }
                    .focused($focusedControl, equals: .playPause)

                    // Seek Forward
                    PlayerControlButton(
                        icon: "goforward.10",
                        size: 60
                    ) {
                        viewModel.seekForward()
                        resetHideTimer()
                    }
                    .focused($focusedControl, equals: .seekForward)
                }

                Spacer()

                // Bottom Bar - Progress and Options
                VStack(spacing: 12) {
                    // Skip Intro Button (when available)
                    if viewModel.showSkipIntroButton {
                        HStack {
                            Spacer()
                            Button(action: {
                                viewModel.skipIntro()
                                resetHideTimer()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "forward.fill")
                                        .font(.headline)
                                    Text("Skip Intro")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.black)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 8)
                    }

                    // Time Display
                    HStack {
                        Text(viewModel.currentTimeFormatted)
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Text(viewModel.remainingTimeFormatted)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 60)

                    // Progress Bar
                    PlayerProgressBar(
                        progress: viewModel.progress,
                        bufferedProgress: viewModel.bufferedProgress
                    )
                    .frame(height: 8)
                    .padding(.horizontal, 60)

                    // Subtitle and Audio Options
                    HStack(spacing: 20) {
                        Spacer()

                        // Subtitle Button
                        Button(action: {
                            showSubtitlePicker = true
                            resetHideTimer()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "captions.bubble")
                                    .font(.headline)
                                Text(viewModel.currentSubtitleName)
                                    .font(.headline)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(viewModel.selectedSubtitleIndex != nil ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedControl, equals: .subtitle)

                        // Bitrate Button
                        Button(action: {
                            showBitratePicker = true
                            resetHideTimer()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "gauge.high")
                                    .font(.headline)
                                Text("\(Int(Double(settingsManager.maxBitrate) / 1_000_000)) Mbps")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedControl, equals: .bitrate)

                        // Audio Button
                        Button(action: {
                            // TODO: Show audio selection sheet
                            resetHideTimer()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.headline)
                                Text("Audio")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .focused($focusedControl, equals: .audio)
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 8)
                }
                .padding(.bottom, 60)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.7),
                        Color.clear,
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(showControls.wrappedValue ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.3), value: showControls.wrappedValue)
            .allowsHitTesting(showControls.wrappedValue) // Only allow interaction when visible
        }
        .onAppear {
            // Start with controls visible and play/pause focused
            showControls.wrappedValue = true
            focusedControl = .playPause
            resetHideTimer()
            // Setup remote commands through coordinator
            coordinator.setupRemoteCommands(viewModel: viewModel) { [weak coordinator] in
                withAnimation {
                    coordinator?.showControls = true
                }
            }
        }
        .onDisappear {
            hideTimer?.invalidate()
            hideTask?.cancel()
            pauseShowTask?.cancel()
            coordinator.removeRemoteCommands()
        }
        .onChange(of: focusedControl) { oldValue, newValue in
            // When user moves focus, show controls and reset timer
            if newValue != nil {
                withAnimation {
                    showControls.wrappedValue = true
                }
                resetHideTimer()
            }
        }
        .onChange(of: coordinator.showControls) { oldValue, newValue in
            // When controls are shown (by remote or otherwise), reset timer
            if newValue {
                resetHideTimer()
                // Restore focus to play/pause when controls become visible
                if focusedControl == nil {
                    focusedControl = .playPause
                }
            }
        }
        .onChange(of: showControls.wrappedValue) { oldValue, newValue in
            // When controls become visible, ensure focus is set
            if newValue && !oldValue {
                // Controls just became visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if focusedControl == nil {
                        focusedControl = .playPause
                    }
                }
            }
        }
        .onChange(of: viewModel.isPlaying) { oldValue, newValue in
            // Handle pause/play state changes
            if !newValue {
                // Video paused - show controls immediately and keep them visible
                print("⏸️ Video paused - showing controls")
                pauseShowTask?.cancel()
                withAnimation {
                    showControls.wrappedValue = true
                }
                // Ensure focus is on play/pause
                focusedControl = .playPause
            } else {
                // Video playing - cancel pause timer and start hide timer
                print("▶️ Video playing - starting auto-hide timer")
                pauseShowTask?.cancel()
                resetHideTimer()
            }
        }
        .onChange(of: viewModel.currentTime) { oldValue, newValue in
            // Detect seeking (time jump larger than normal playback)
            let timeDiff = abs(newValue - oldValue)
            if timeDiff > 2.0 { // More than 2 seconds = seeking
                print("⏩ Seeking detected - showing controls")
                withAnimation {
                    showControls.wrappedValue = true
                }
                // Don't auto-hide while paused
                if viewModel.isPlaying {
                    resetHideTimer()
                }
            }
        }
        // Intercept Menu/Back button press
        .onExitCommand {
            // Always show controls first if they're hidden
            if !showControls.wrappedValue {
                withAnimation {
                    showControls.wrappedValue = true
                }
                focusedControl = .playPause
                resetHideTimer()
            } else if focusedControl != .close {
                // Controls visible but not on close button - move focus to close
                focusedControl = .close
            }
            // If on close button, let it propagate to exit
        }
        .sheet(isPresented: $showSubtitlePicker) {
            SubtitlePickerModal(viewModel: viewModel)
        }
        .sheet(isPresented: $showBitratePicker) {
            BitratePickerModal(settingsManager: settingsManager)
        }
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTask?.cancel()

        // Don't auto-hide controls when video is paused
        guard viewModel.isPlaying else {
            print("🎮 Video paused - controls will stay visible")
            return
        }

        // Use Task for async delay - works better with @State in SwiftUI
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

            guard !Task.isCancelled else { return }

            withAnimation {
                coordinator.showControls = false
            }
        }
    }
}

// MARK: - Player Control Button

struct PlayerControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(.white)
                .frame(width: size * 1.5, height: size * 1.5)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isFocused ? 0.25 : 0.0))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isFocused ? 4 : 0)
                )
                .scaleEffect(isFocused ? 1.15 : 1.0)
                .shadow(
                    color: isFocused ? .white.opacity(0.5) : .clear,
                    radius: isFocused ? 30 : 0
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Bar

struct PlayerProgressBar: View {
    let progress: Double  // 0-1
    let bufferedProgress: Double  // 0-1

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.3))

                // Buffered
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: geometry.size.width * bufferedProgress)

                // Progress
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * progress)
            }
            .cornerRadius(4)
        }
    }
}

// MARK: - Debug Stats Overlay

struct DebugStatsOverlay: View {
    let stats: DebugStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack {
                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    Text("DEBUG STATS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 4)

                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.bottom, 4)

                    // Video Quality
                    StatRow(label: "Quality:", value: stats.videoQuality.uppercased())

                    // Video Codec
                    StatRow(label: "Codec:", value: stats.videoCodec.uppercased())

                    // Max Bitrate
                    StatRow(label: "Max Bitrate:", value: stats.maxBitrateMbps)

                    // Observed Bitrate
                    StatRow(
                        label: "Current:",
                        value: stats.observedBitrateMbps,
                        highlight: stats.observedBitrate > 0
                    )

                    // Audio Quality
                    StatRow(label: "Audio:", value: stats.audioQuality.uppercased())

                    // Subtitle Status
                    StatRow(
                        label: "Subtitles:",
                        value: stats.subtitleMode.uppercased(),
                        highlight: stats.subtitleMode != "off"
                    )

                    // Buffer Status
                    StatRow(label: "Buffer:", value: stats.bufferPercent)
                }
                .font(.caption2)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.trailing, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 85, alignment: .leading)

            Text(value)
                .foregroundColor(highlight ? Color.green : Color.white)
                .fontWeight(highlight ? .semibold : .regular)
                .frame(alignment: .leading)
        }
    }
}

// MARK: - Error View

struct ErrorPlayerView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 80))
                .foregroundColor(.red.opacity(0.8))

            Text("Playback Error")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)

            FocusableButton(title: "Try Again", style: .primary) {
                onRetry()
            }
            .frame(width: 300)
        }
    }
}

// MARK: - Preview

#Preview {
    let mockItem = MediaItem(
        id: "1",
        name: "The Matrix",
        type: "Movie",
        overview: nil,
        productionYear: 1999,
        communityRating: 8.7,
        officialRating: "R",
        runTimeTicks: 8_160_000_000,
        imageTags: ImageTags(primary: "tag1", backdrop: nil, thumb: nil, logo: nil, banner: nil),
        imageBlurHashes: nil,
        userData: nil,
        seriesName: nil,
        seriesId: nil,
        seasonId: nil,
        indexNumber: nil,
        parentIndexNumber: nil,
        premiereDate: nil,
        genres: nil,
        studios: nil,
        people: nil,
        taglines: nil,
        mediaSources: nil
    )

    VideoPlayerView(
        item: mockItem,
        authService: AuthenticationService()
    )
    .environmentObject(NavigationManager())
}
