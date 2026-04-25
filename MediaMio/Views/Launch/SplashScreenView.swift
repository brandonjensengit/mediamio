//
//  SplashScreenView.swift
//  MediaMio
//
//  Premium Netflix-style launch screen with animated logo
//

import SwiftUI
import os

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthenticationService
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var minimumTimeElapsed = false
    @State private var loadingState: LoadingState = .loading

    /// Paired begin/end tokens for the splash-timing signpost interval. The
    /// `id` is shared across the wrapper interval and the two intermediate
    /// events ("Content Loaded", "Minimum Floor") so Instruments groups them
    /// onto a single row in Points of Interest.
    @State private var splashSignpostID: OSSignpostID?
    @State private var splashSignpostInterval: OSSignpostIntervalState?

    enum LoadingState: Equatable {
        case loading
        case success
        case error(String)
    }

    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                // Typographic wordmark — matches gloxx.ai brand treatment
                // (Space Grotesk Bold, 0.25em tracking, uppercase). Replaces
                // the combined owl+wordmark PNG.
                GloxxWordmark(size: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)

                // Error message (if needed)
                if case .error(let message) = loadingState {
                    VStack(spacing: 16) {
                        Text("Connection Error")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(message)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Retry") {
                            loadingState = .loading
                            loadJellyfinData()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Constants.Colors.accent)
                    }
                    .padding()
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Begin splash-timing interval. Capture the id once so the two
            // intermediate events ("Content Loaded", "Minimum Floor") and the
            // matching `endInterval` all share the same Instruments row.
            let id = SplashSignposts.signposter.makeSignpostID()
            splashSignpostID = id
            splashSignpostInterval = SplashSignposts.signposter.beginInterval(
                "Splash", id: id, "onAppear"
            )

            // Play startup sound immediately
            AudioManager.shared.playStartupSound()

            // Animate icon in with smooth spring animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            // Start minimum timer
            loadJellyfinData()
        }
        .onChange(of: appState.contentLoaded) { _, isLoaded in
            if isLoaded {
                if let id = splashSignpostID {
                    SplashSignposts.signposter.emitEvent("Content Loaded", id: id)
                }
                checkIfReadyToTransition()
            }
        }
    }

    private func loadJellyfinData() {
        // Start minimum time timer
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                minimumTimeElapsed = true
                if let id = splashSignpostID {
                    SplashSignposts.signposter.emitEvent("Minimum Floor", id: id)
                }
                checkIfReadyToTransition()
            }
        }
    }

    private func checkIfReadyToTransition() {
        // On the authenticated branch, wait for HomeViewModel to signal its
        // first content load has completed. On the unauthenticated branch
        // (fresh install, logged out, saved-token invalidated), no one is
        // going to flip `contentLoaded` — we're routing to ServerEntryView,
        // which has no "content" to load — so dismissing after the minimum
        // time is the correct terminal state. Without this branch, the
        // splash overlay hangs forever on a new sim / new user.
        let contentReady = appState.contentLoaded || !authService.isAuthenticated
        guard minimumTimeElapsed && contentReady else {
            return
        }

        loadingState = .success
        if let interval = splashSignpostInterval {
            SplashSignposts.signposter.endInterval("Splash", interval, "dismiss")
            splashSignpostInterval = nil
        }
        withAnimation(.easeOut(duration: 0.5)) {
            isActive = false
        }
    }
}
