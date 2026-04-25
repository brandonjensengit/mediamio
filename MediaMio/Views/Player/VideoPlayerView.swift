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
    let item: MediaItem
    let playbackMode: PlaybackMode
    let subtitleDisplay: String?
    let showSkipIntro: Bool
    let showSkipCredits: Bool
    /// Mirrors the VM's `playbackRate`. Carried as a prop so SwiftUI knows
    /// to re-run `updateUIViewController` when the rate changes — which is
    /// what triggers `syncPlaybackRateMenu` to rebuild the speedometer
    /// menu's checkmark on the active rate (QA-11).
    let playbackRate: Float
    let onSkipIntro: () -> Void
    let onSkipCredits: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        DebugLog.playback("🎥 Creating AVPlayerViewController (SIMPLE)")
        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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

        // Add custom info view controllers for bitrate, audio quality, and
        // the read-only "Playback Info" pane (codec / container / range /
        // play method). Order here is the order they appear as tabs inside
        // the slide-down info panel — put Playback Info first so it's the
        // first thing a debugging user sees.
        let info = PlaybackInfoBuilder.build(
            item: item,
            mode: playbackMode,
            subtitleDisplay: subtitleDisplay,
            maxStreamingBitrate: settingsManager.maxBitrate
        )
        let playbackInfoVC = PlaybackInfoViewController(info: info)
        let bitrateVC = BitrateSelectionViewController(settingsManager: settingsManager)
        let audioQualityVC = AudioQualitySelectionViewController(settingsManager: settingsManager)

        controller.customInfoViewControllers = [playbackInfoVC, bitrateVC, audioQualityVC]
        context.coordinator.playbackInfoVC = playbackInfoVC

        // Apple tvOS contract for skip actions + playback speed. Set an
        // initial pass here; `updateUIViewController` refreshes on every
        // SwiftUI invalidation so the chips appear/disappear in sync with
        // `viewModel.showSkipIntroButton` / `showSkipCreditsButton`.
        syncContextualActions(on: controller)
        syncPlaybackRateMenu(on: controller)

        DebugLog.playback("   Player: \(player)")
        DebugLog.playback("   Player status: \(player.status.rawValue)")
        DebugLog.playback("   Player rate: \(player.rate)")
        DebugLog.playback("   Custom info VCs: \(controller.customInfoViewControllers.count)")

        if let item = player.currentItem {
            DebugLog.playback("   Current item: \(item)")
            DebugLog.playback("   Item status: \(item.status.rawValue)")
            DebugLog.playback("   Item duration: \(item.duration.seconds)s")

            if let error = item.error {
                DebugLog.playback("   ❌ ITEM ERROR: \(error)")
            }

            // Check after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                DebugLog.playback("📊 Status check after 1s:")
                DebugLog.playback("   Item status: \(item.status.rawValue)")
                DebugLog.playback("   Presentation size: \(item.presentationSize)")
                DebugLog.playback("   Tracks: \(item.tracks.count)")

                if let error = item.error {
                    DebugLog.playback("   ❌ ERROR: \(error)")
                }
            }
        } else {
            DebugLog.playback("   ⚠️ No current item!")
        }

        DebugLog.playback("✅ AVPlayerViewController created with native controls + custom info")
        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            DebugLog.playback("🔄 Updating player")
            uiViewController.player = player
        }
        // Refresh the Playback Info pane so failover-to-transcode or a
        // subtitle change shows up the next time the user slides down the
        // info panel (or immediately if they have it open).
        let info = PlaybackInfoBuilder.build(
            item: item,
            mode: playbackMode,
            subtitleDisplay: subtitleDisplay,
            maxStreamingBitrate: settingsManager.maxBitrate
        )
        context.coordinator.playbackInfoVC?.update(info: info)

        syncContextualActions(on: uiViewController)
        syncPlaybackRateMenu(on: uiViewController)
    }

    // MARK: - tvOS HUD wiring

    /// Drive the Apple "contextual action" chip (lower-right of the
    /// transport bar) from the VM's skip-button state. Empty array ⇒ no
    /// chip, which is what Apple renders when the intro/credits window
    /// is not active.
    private func syncContextualActions(on controller: AVPlayerViewController) {
        var actions: [UIAction] = []
        if showSkipIntro {
            actions.append(UIAction(
                title: "Skip Intro",
                image: UIImage(systemName: "forward.fill")
            ) { _ in onSkipIntro() })
        }
        if showSkipCredits {
            actions.append(UIAction(
                title: "Skip Credits",
                image: UIImage(systemName: "forward.end.fill")
            ) { _ in onSkipCredits() })
        }
        controller.contextualActions = actions
    }

    /// Publish the playback-speed menu as a transport-bar custom menu item.
    /// Uses `AVPlayer.defaultRate` (tvOS 16+) so the user's chosen speed
    /// persists across pause/seek — `rate` goes to 0 when paused, which
    /// would otherwise flip the checkmark back to 1× incorrectly.
    private func syncPlaybackRateMenu(on controller: AVPlayerViewController) {
        let options: [(label: String, value: Float)] = [
            ("0.5×",  0.5),
            ("1×",    1.0),
            ("1.25×", 1.25),
            ("1.5×",  1.5),
            ("2×",    2.0)
        ]
        let current = player.defaultRate > 0 ? player.defaultRate : 1.0
        let children = options.map { option -> UIAction in
            UIAction(
                title: option.label,
                state: abs(current - option.value) < 0.01 ? .on : .off
            ) { [player] _ in
                player.defaultRate = option.value
                // Apply live if playing; leave paused state alone so
                // selecting a speed doesn't unpause the user.
                if player.rate != 0 {
                    player.rate = option.value
                }
            }
        }
        let menu = UIMenu(
            title: "Playback Speed",
            image: UIImage(systemName: "speedometer"),
            children: children
        )
        controller.transportBarCustomMenuItems = [menu]
    }

    // MARK: - Coordinator for handling AVPlayerViewController delegate

    /// Delegate + side-channel for mutating the read-only Playback Info
    /// pane after the player is created. tvOS auto-dismisses on menu press
    /// by default; add real delegate methods (e.g. `playerViewController
    /// WillBeginDismissalTransition`) here if you need to react to player
    /// lifecycle events.
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        weak var playbackInfoVC: PlaybackInfoViewController?
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let item: MediaItem
    let authService: AuthenticationService
    let startPositionTicks: Int64?
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel: VideoPlayerViewModel
    @StateObject private var settingsManager = SettingsManager()

    init(
        item: MediaItem,
        authService: AuthenticationService,
        apiClient: JellyfinAPIClient,
        startPositionTicks: Int64? = nil
    ) {
        self.item = item
        self.authService = authService
        self.startPositionTicks = startPositionTicks

        // Initialize ViewModel
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            item: item,
            authService: authService,
            apiClient: apiClient,
            initialStartPositionTicks: startPositionTicks
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // CLEAN: Native AVPlayerViewController with custom info view controllers.
            // Skip Intro / Skip Credits ride on `controller.contextualActions`
            // (Apple's tvOS-15+ contract) rather than a custom SwiftUI overlay,
            // so they animate in/out with the native "Up Next" chrome.
            if let player = viewModel.player {
                SimpleVideoPlayerRepresentable(
                    player: player,
                    settingsManager: settingsManager,
                    item: viewModel.item,
                    playbackMode: viewModel.currentPlaybackMode,
                    subtitleDisplay: viewModel.currentSubtitleDisplay,
                    showSkipIntro: viewModel.showSkipIntroButton,
                    showSkipCredits: viewModel.showSkipCreditsButton,
                    playbackRate: viewModel.playbackRate,
                    onSkipIntro: { viewModel.skipIntro() },
                    onSkipCredits: { viewModel.skipCredits() }
                )
                    .ignoresSafeArea()
                    // Auto-play is the VM's responsibility — its `.readyToPlay`
                    // status sink runs after the resume-position seek lands and
                    // honors the `shouldAutoPlayOnReady` flag (so a paused user
                    // who changes bitrate stays paused). Calling
                    // `startPlayback()` here would re-trigger play on every
                    // mid-playback reload, defeating that policy.
                    .onDisappear {
                        DebugLog.playback("⏸️ Pausing playback")
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
        mediaSources: nil,
        criticRating: nil,
        providerIds: nil,
        externalUrls: nil,
        remoteTrailers: nil,
        chapters: nil,
        parentLogoItemId: nil,
        parentLogoImageTag: nil
    )

    VideoPlayerView(
        item: mockItem,
        authService: AuthenticationService(),
        apiClient: JellyfinAPIClient()
    )
    .environmentObject(NavigationManager())
}
