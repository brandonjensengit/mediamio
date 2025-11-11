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

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎥 Creating AVPlayerViewController (SIMPLE)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let controller = AVPlayerViewController()
        controller.player = player

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
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let item: MediaItem
    let authService: AuthenticationService
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel: VideoPlayerViewModel
    @StateObject private var settingsManager = SettingsManager()

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

            // CLEAN: Native AVPlayerViewController with custom info view controllers
            if let player = viewModel.player {
                SimpleVideoPlayerRepresentable(player: player, settingsManager: settingsManager)
                    .ignoresSafeArea()
                    .onAppear {
                        print("▶️ Starting playback")
                        viewModel.startPlayback()
                    }
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
