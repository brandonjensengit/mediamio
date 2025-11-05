//
//  SplashScreenView.swift
//  MediaMio
//
//  Premium Netflix-style launch screen with animated logo
//

import SwiftUI

struct SplashScreenView: View {
    @Binding var isActive: Bool
    @EnvironmentObject var appState: AppState
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var minimumTimeElapsed = false
    @State private var loadingState: LoadingState = .loading

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
                // MediaMio logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
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
                        .tint(Color(hex: "667eea"))
                    }
                    .padding()
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
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
                checkIfReadyToTransition()
            }
        }
    }

    private func checkIfReadyToTransition() {
        // Only transition when both conditions are met
        guard minimumTimeElapsed && appState.contentLoaded else {
            return
        }

        loadingState = .success
        withAnimation(.easeOut(duration: 0.5)) {
            isActive = false
        }
    }
}
