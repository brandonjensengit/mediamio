//
//  VideoPlayerView.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 5: Netflix-Style Video Player
//

import SwiftUI
import AVKit

// MARK: - Simple Player Wrapper

struct SimpleVideoPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let settingsManager: SettingsManager

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎥 Creating AVPlayerViewController (SIMPLE)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator

        // CRITICAL: Show native controls for tvOS
        controller.showsPlaybackControls = true

        // CRITICAL: Enable closed caption display (for CC-format subtitles)
        #if os(tvOS)
        // On tvOS, we need to ensure subtitles/CC are allowed to display
        controller.allowsPictureInPicturePlayback = true
        #endif

        // Add custom info view controllers for bitrate and audio quality
        let bitrateVC = BitrateSelectionViewController(settingsManager: settingsManager)
        let audioQualityVC = AudioQualitySelectionViewController(settingsManager: settingsManager)

        controller.customInfoViewControllers = [bitrateVC, audioQualityVC]

        print("   Player: \(player)")
        print("   Player status: \(player.status.rawValue)")
        print("   Player rate: \(player.rate)")
        print("   Custom info VCs: \(controller.customInfoViewControllers.count)")

        if let item = player.currentItem {
            print("   Current item: \(item)")
            print("   Item status: \(item.status.rawValue)")
            print("   Item duration: \(item.duration.seconds)s")

            if let error = item.error {
                print("   ❌ ITEM ERROR: \(error)")
            }

            // Check after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("📊 Status check after 1s:")
                print("   Item status: \(item.status.rawValue)")
                print("   Presentation size: \(item.presentationSize)")
                print("   Tracks: \(item.tracks.count)")

                if let error = item.error {
                    print("   ❌ ERROR: \(error)")
                }
            }
        } else {
            print("   ⚠️ No current item!")
        }

        print("✅ AVPlayerViewController created with native controls + custom info")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            print("🔄 Updating player")
            uiViewController.player = player
        }
    }

    // MARK: - Coordinator for handling AVPlayerViewController delegate

    /// Placeholder delegate. tvOS auto-dismisses on menu press by default;
    /// add real delegate methods (e.g. `playerViewControllerWillBeginDismissalTransition`)
    /// here if you need to react to player lifecycle events.
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {}
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let item: MediaItem
    let authService: AuthenticationService
    let startPositionTicks: Int64?
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel: VideoPlayerViewModel
    @StateObject private var settingsManager = SettingsManager()

    init(item: MediaItem, authService: AuthenticationService, startPositionTicks: Int64? = nil) {
        self.item = item
        self.authService = authService
        self.startPositionTicks = startPositionTicks

        // Initialize ViewModel
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            item: item,
            authService: authService,
            initialStartPositionTicks: startPositionTicks
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // CLEAN: Native AVPlayerViewController with custom info view controllers
            if let player = viewModel.player {
                SimpleVideoPlayerRepresentable(player: player, settingsManager: settingsManager)
                    .ignoresSafeArea()
                    // Auto-play is the VM's responsibility — its `.readyToPlay`
                    // status sink runs after the resume-position seek lands and
                    // honors the `shouldAutoPlayOnReady` flag (so a paused user
                    // who changes bitrate stays paused). Calling
                    // `startPlayback()` here would re-trigger play on every
                    // mid-playback reload, defeating that policy.
                    .onDisappear {
                        print("⏸️ Pausing playback")
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

            SkipMarkerOverlay(viewModel: viewModel)
        }
        .task {
            await viewModel.loadVideoURL()
        }
        .onDisappear {
            // Clean up when leaving the player
            viewModel.cleanup()
        }
    }
}

// MARK: - Skip Marker Overlay

/// Bottom-right overlay for Skip Intro / Skip Credits buttons. Sits above
/// the native `AVPlayerViewController` controls; the focus engine can reach
/// the buttons when the native controls are dismissed. Both buttons are
/// driven off `@Published` state on the VM that's re-published from
/// `IntroCreditsController`.
struct SkipMarkerOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 16) {
                    if viewModel.showSkipIntroButton {
                        SkipButton(title: "Skip Intro", icon: "forward.fill") {
                            viewModel.skipIntro()
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    if viewModel.showSkipCreditsButton {
                        SkipButton(title: "Skip Credits", icon: "forward.end.fill") {
                            viewModel.skipCredits()
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.trailing, 80)
                .padding(.bottom, 80)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showSkipIntroButton)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showSkipCreditsButton)
        .allowsHitTesting(viewModel.showSkipIntroButton || viewModel.showSkipCreditsButton)
    }
}

private struct SkipButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @FocusState private var hasFocus: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(hasFocus ? Color.white : Color.black.opacity(0.7))
            .foregroundColor(hasFocus ? .black : .white)
            .cornerRadius(10)
            .scaleEffect(hasFocus ? 1.05 : 1.0)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .animation(.easeInOut(duration: 0.2), value: hasFocus)
        }
        .buttonStyle(.plain)
        .focused($hasFocus)
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
        mediaSources: nil,
        criticRating: nil,
        providerIds: nil,
        externalUrls: nil,
        remoteTrailers: nil,
        chapters: nil
    )

    VideoPlayerView(
        item: mockItem,
        authService: AuthenticationService()
    )
    .environmentObject(NavigationManager())
}
