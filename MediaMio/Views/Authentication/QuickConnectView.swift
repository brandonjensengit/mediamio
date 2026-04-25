//
//  QuickConnectView.swift
//  MediaMio
//
//  Passwordless login flow driven by the Jellyfin Quick Connect endpoints.
//  The view initiates a session on appear, displays the returned 6-digit
//  code, and polls every 2s until the user approves the request from the
//  Jellyfin web UI on another device — then trades the secret for a real
//  access token via AuthenticationService.
//
//  Constraint: this view never stores the secret beyond its own lifetime
//  and cancels polling on disappear to avoid leaking a Task into the session
//  after the user backs out.
//

import SwiftUI

struct QuickConnectView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    let serverURL: String
    let rememberMe: Bool
    /// Human-readable name of the server, passed through to the saved-
    /// servers store so the picker shows "My Jellyfin" instead of the raw
    /// URL. Optional for back-compat with older preview callers.
    let serverName: String?

    init(serverURL: String, rememberMe: Bool, serverName: String? = nil) {
        self.serverURL = serverURL
        self.rememberMe = rememberMe
        self.serverName = serverName
    }

    @State private var state: FlowState = .initiating
    @State private var secret: String?
    @State private var code: String?
    @State private var errorMessage: String?
    @State private var pollingTask: Task<Void, Never>?

    enum FlowState: Equatable {
        case initiating
        case waitingForApproval
        case authenticating
        case succeeded
        case failed
    }

    // Jellyfin approves in seconds if the user is attentive; 2s polling is
    // gentle on the server and feels immediate to the user. Cap the total
    // wait at 5 minutes so a forgotten session eventually cleans up.
    private let pollInterval: TimeInterval = 2.0
    private let maxPollDurationSeconds: TimeInterval = 5 * 60

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            VStack(spacing: 40) {
                header
                    .padding(.top, 60)

                Spacer()

                mainContent

                Spacer()

                FocusableButton(title: "Cancel", style: .secondary) {
                    cancel()
                }
                .frame(width: 400)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 80)
        }
        .task { await start() }
        .onDisappear { pollingTask?.cancel() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(Constants.Colors.primary)

            Text("Quick Connect")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Sign in without a password")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch state {
        case .initiating:
            progress(message: "Preparing Quick Connect…")

        case .waitingForApproval:
            waitingSection

        case .authenticating:
            progress(message: "Signing in…")

        case .succeeded:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                Text("Signed in").font(.title).foregroundColor(.white)
            }

        case .failed:
            failedSection
        }
    }

    private var waitingSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("1. Open Jellyfin on your phone or computer")
                Text("2. Go to Settings → Quick Connect")
                Text("3. Enter this code:")
            }
            .font(.title3)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            Text(code ?? "------")
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(24)
                .padding(.horizontal, 80)
                .padding(.vertical, 40)
                .background(Constants.Colors.surface1)
                .cornerRadius(Constants.UI.cornerRadius)

            HStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Waiting for approval…")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var failedSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            Text(errorMessage ?? "Quick Connect failed.")
                .font(.title3)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 800)

            FocusableButton(title: "Try Again", style: .primary) {
                Task { await start() }
            }
            .frame(width: 400)
        }
    }

    private func progress(message: String) -> some View {
        VStack(spacing: 24) {
            ProgressView().scaleEffect(1.6)
            Text(message).font(.title3).foregroundColor(.white)
        }
    }

    // MARK: - Flow

    private func start() async {
        pollingTask?.cancel()
        state = .initiating
        errorMessage = nil
        secret = nil
        code = nil

        do {
            let result = try await authService.initiateQuickConnect(serverURL: serverURL)
            self.secret = result.secret
            self.code = result.code
            self.state = .waitingForApproval
            self.pollingTask = Task { await poll(secret: result.secret) }
        } catch {
            self.errorMessage = "Couldn't start Quick Connect: \(error.localizedDescription)"
            self.state = .failed
        }
    }

    private func poll(secret: String) async {
        let deadline = Date().addingTimeInterval(maxPollDurationSeconds)

        while !Task.isCancelled && Date() < deadline {
            do {
                let result = try await authService.pollQuickConnect(secret: secret)
                if result.authenticated {
                    await finalize(secret: secret)
                    return
                }
            } catch {
                // Transient network errors during polling shouldn't kill the
                // flow — the user may approve a few seconds later. The retry
                // loop in the API client already handles real transients;
                // anything that escapes here (e.g. 404 if the server dropped
                // the session) we surface and stop polling.
                print("❌ Quick Connect poll error: \(error)")
                self.errorMessage = "Quick Connect session ended: \(error.localizedDescription)"
                self.state = .failed
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        if !Task.isCancelled {
            errorMessage = "Quick Connect timed out. Try again."
            state = .failed
        }
    }

    private func finalize(secret: String) async {
        state = .authenticating
        do {
            try await authService.completeQuickConnect(
                serverURL: serverURL,
                secret: secret,
                rememberMe: rememberMe,
                serverName: serverName
            )
            state = .succeeded
            // Give the checkmark a brief moment to register, then dismiss.
            try? await Task.sleep(nanoseconds: 600_000_000)
            dismiss()
        } catch {
            errorMessage = "Sign-in failed: \(error.localizedDescription)"
            state = .failed
        }
    }

    private func cancel() {
        pollingTask?.cancel()
        dismiss()
    }
}

#Preview {
    QuickConnectView(serverURL: "http://192.168.1.100:8096", rememberMe: true)
        .environmentObject(AuthenticationService(apiClient: JellyfinAPIClient()))
}
