//
//  IntroCreditsController.swift
//  MediaMio
//
//  Phase A refactor: extracted from VideoPlayerViewModel (lines 844–927 of
//  the original). Owns the integration with Jellyfin's intro-skipper plugin:
//  fetches intro markers from `/Shows/{id}/IntroTimestamps`, exposes a
//  reactive "should we show the Skip Intro button" boolean, and performs the
//  actual seek when the user (or auto-skip) triggers it.
//
//  Constraint: knows nothing about subtitle, fallback, or session-reporting
//  concerns. Only intro/credits markers.
//

import AVFoundation
import Combine
import Foundation

/// Manages the "Skip Intro" and "Skip Credits" UX. Holds the fetched marker
/// windows and decides, each time a `currentTime` tick arrives, whether
/// either skip button should be shown and whether to auto-skip based on user
/// settings.
@MainActor
final class IntroCreditsController: ObservableObject {
    @Published private(set) var showSkipIntroButton: Bool = false
    @Published private(set) var showSkipCreditsButton: Bool = false

    private let baseURL: String
    private let accessToken: String
    private let itemId: String
    private let settingsManager: SettingsManager
    private let session: URLSession

    private var introStart: Double?
    private var introEnd: Double?
    private var creditsStart: Double?
    private var creditsEnd: Double?
    private var hasSkippedIntro: Bool = false
    private var hasSkippedCredits: Bool = false

    init(
        baseURL: String,
        accessToken: String,
        itemId: String,
        settingsManager: SettingsManager,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.itemId = itemId
        self.settingsManager = settingsManager
        self.session = session
    }

    /// Fetch intro markers from Jellyfin's intro-skipper plugin.
    /// Silent on 404 — most items don't have markers.
    func fetchMarkers() async {
        print("🎬 Fetching intro markers from Jellyfin")

        guard let url = URL(string: "\(baseURL)/Shows/\(itemId)/IntroTimestamps") else {
            print("❌ Failed to create intro markers URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            switch http.statusCode {
            case 200:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let showIntros = json["ShowIntroTimestamps"] as? [String: Any],
                   let markers = showIntros.values.first as? [String: Any] {
                    if let start = markers["IntroStart"] as? Double,
                       let end = markers["IntroEnd"] as? Double {
                        introStart = start
                        introEnd = end
                        print("✅ Intro detected: \(formatTime(start)) - \(formatTime(end))")
                    }
                    if let start = markers["CreditsStart"] as? Double,
                       let end = markers["CreditsEnd"] as? Double {
                        creditsStart = start
                        creditsEnd = end
                        print("✅ Credits detected: \(formatTime(start)) - \(formatTime(end))")
                    }
                }
            case 404:
                print("ℹ️ No intro markers available for this item")
            default:
                print("⚠️ Intro markers request returned: \(http.statusCode)")
            }
        } catch {
            print("⚠️ Failed to fetch intro markers: \(error)")
        }
    }

    /// Called from the player's periodic time observer. Updates the visible
    /// button state for both intro and credits windows, and triggers
    /// auto-skip if the user has it enabled.
    func tick(currentTime: Double, player: AVPlayer?) {
        tickIntro(currentTime: currentTime, player: player)
        tickCredits(currentTime: currentTime, player: player)
    }

    private func tickIntro(currentTime: Double, player: AVPlayer?) {
        guard let start = introStart, let end = introEnd, !hasSkippedIntro else { return }
        let isInIntro = currentTime >= start && currentTime <= end

        if isInIntro {
            if settingsManager.showSkipIntroButton {
                showSkipIntroButton = true
            }
            if settingsManager.autoSkipIntros {
                let countdown = settingsManager.skipIntroCountdown
                if countdown > 0 {
                    if abs(currentTime - start) < 1.0 {
                        print("⏳ Auto-skipping intro in \(countdown) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(countdown)) { [weak self] in
                            guard let self = self, !self.hasSkippedIntro else { return }
                            self.skip(player: player)
                        }
                    }
                } else {
                    skip(player: player)
                }
            }
        } else if currentTime > end {
            showSkipIntroButton = false
        }
    }

    private func tickCredits(currentTime: Double, player: AVPlayer?) {
        guard let start = creditsStart, let end = creditsEnd, !hasSkippedCredits else { return }
        let isInCredits = currentTime >= start && currentTime <= end

        if isInCredits {
            if settingsManager.showSkipCreditsButton {
                showSkipCreditsButton = true
            }
            if settingsManager.autoSkipCredits {
                let countdown = settingsManager.skipCreditsCountdown
                if countdown > 0 {
                    if abs(currentTime - start) < 1.0 {
                        print("⏳ Auto-skipping credits in \(countdown) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(countdown)) { [weak self] in
                            guard let self = self, !self.hasSkippedCredits else { return }
                            self.skipCredits(player: player)
                        }
                    }
                } else {
                    skipCredits(player: player)
                }
            }
        } else if currentTime > end {
            showSkipCreditsButton = false
        }
    }

    /// User-triggered skip (or auto-skip with zero countdown). Seeks the
    /// player to the end of the intro and dismisses the button.
    func skip(player: AVPlayer?) {
        guard let player = player, let end = introEnd else { return }
        print("⏭️ Skipping intro to: \(formatTime(end))")
        let seekTime = CMTime(seconds: end, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        hasSkippedIntro = true
        showSkipIntroButton = false
    }

    /// User-triggered credits skip. Seeks to the end of the credits window,
    /// which for most content equals "end of playback" and causes the
    /// player's didPlayToEndTime notification to fire.
    func skipCredits(player: AVPlayer?) {
        guard let player = player, let end = creditsEnd else { return }
        print("⏭️ Skipping credits to: \(formatTime(end))")
        let seekTime = CMTime(seconds: end, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        hasSkippedCredits = true
        showSkipCreditsButton = false
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
