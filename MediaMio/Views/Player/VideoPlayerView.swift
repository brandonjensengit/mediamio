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

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false  // Hide default controls (we have custom ones)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update if needed
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let item: MediaItem
    let authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel: VideoPlayerViewModel

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

            // AVPlayerViewController (instead of SwiftUI VideoPlayer)
            if let player = viewModel.player {
                CustomVideoPlayerController(player: player)
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

            // Custom Controls Overlay (Our Netflix-style controls)
            PlayerControlsOverlay(
                viewModel: viewModel,
                onClose: {
                    navigationManager.closePlayer()
                }
            )
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
}

// MARK: - Player Controls Overlay

struct PlayerControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let onClose: () -> Void

    @StateObject private var coordinator = RemoteCommandCoordinator()
    @State private var hideTimer: Timer?
    @State private var hideTask: Task<Void, Never>?
    @FocusState private var focusedControl: PlayerControl?

    private var showControls: Binding<Bool> {
        $coordinator.showControls
    }

    enum PlayerControl {
        case playPause
        case seekBackward
        case seekForward
        case close
    }

    var body: some View {
        ZStack {
            // Always-present invisible button to ensure controls can come back
            if !showControls.wrappedValue {
                Button("") {
                    withAnimation {
                        showControls.wrappedValue = true
                    }
                    resetHideTimer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.01) // Nearly invisible but focusable
                .buttonStyle(.plain)
                .focused($focusedControl, equals: .playPause)
            }

            if showControls.wrappedValue {
                VStack {
                    // Top Bar
                    HStack {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.item.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            if let seriesName = viewModel.item.seriesName,
                               let seasonNum = viewModel.item.parentIndexNumber,
                               let episodeNum = viewModel.item.indexNumber {
                                Text("\(seriesName) · S\(seasonNum):E\(episodeNum)")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
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

                    // Bottom Bar - Progress
                    VStack(spacing: 12) {
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
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showControls.wrappedValue)
            }
        }
        .onAppear {
            focusedControl = .playPause
            resetHideTimer()
            setupRemoteCommands()
        }
        .onDisappear {
            hideTimer?.invalidate()
            hideTask?.cancel()
            removeRemoteCommands()
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
            }
        }
        // Intercept Menu button to show controls if hidden
        .onExitCommand {
            if !showControls.wrappedValue {
                // Controls hidden: show them instead of exiting
                withAnimation {
                    showControls.wrappedValue = true
                }
                resetHideTimer()
            }
            // If controls visible, let the close button be used to exit
            // (Menu button will propagate and exit the fullScreenCover)
        }
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTask?.cancel()

        // Use Task for async delay - works better with @State in SwiftUI
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

            guard !Task.isCancelled else { return }

            withAnimation {
                coordinator.showControls = false
            }
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [coordinator, viewModel] _ in
            Task { @MainActor in
                viewModel.startPlayback()
                withAnimation {
                    coordinator.showControls = true
                }
            }
            print("🎮 Remote: Play command")
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [coordinator, viewModel] _ in
            Task { @MainActor in
                viewModel.pausePlayback()
                withAnimation {
                    coordinator.showControls = true
                }
            }
            print("🎮 Remote: Pause command")
            return .success
        }

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [coordinator, viewModel] _ in
            Task { @MainActor in
                viewModel.togglePlayPause()
                withAnimation {
                    coordinator.showControls = true
                }
            }
            print("🎮 Remote: Toggle play/pause")
            return .success
        }

        // Skip forward
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [coordinator, viewModel] _ in
            Task { @MainActor in
                viewModel.seekForward()
                withAnimation {
                    coordinator.showControls = true
                }
            }
            print("🎮 Remote: Skip forward 10s")
            return .success
        }

        // Skip backward
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [coordinator, viewModel] _ in
            Task { @MainActor in
                viewModel.seekBackward()
                withAnimation {
                    coordinator.showControls = true
                }
            }
            print("🎮 Remote: Skip backward 10s")
            return .success
        }

        print("🎮 Remote commands enabled via MPRemoteCommandCenter")
    }

    private func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)

        print("🎮 Remote commands disabled")
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
                        .fill(Color.white.opacity(isFocused ? 0.2 : 0.0))
                )
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .shadow(
                    color: isFocused ? .white.opacity(0.3) : .clear,
                    radius: isFocused ? 20 : 0
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
        taglines: nil
    )

    VideoPlayerView(
        item: mockItem,
        authService: AuthenticationService()
    )
    .environmentObject(NavigationManager())
}
