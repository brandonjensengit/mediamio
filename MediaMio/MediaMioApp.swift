//
//  MediaMioApp.swift
//  MediaMio
//
//  Created by Brandon Jensen on 10/31/25.
//  Phase 1: Netflix-Level Navigation Refactor
//

import SwiftUI

@main
struct MediaMioApp: App {
    @StateObject private var authService: AuthenticationService
    @StateObject private var appEnv: AppEnvironment
    @StateObject private var savedServers: SavedServersStore
    @StateObject private var appState = AppState()

    init() {
        // One JellyfinAPIClient lives at the app root and is injected into
        // every consumer (AuthenticationService, AppEnvironment, and from
        // there into screens that need it). Sharing the URLSession means a
        // single HTTP/2 connection pool, single URLCache, and one source of
        // truth for `baseURL` / `accessToken` on session change.
        let client = JellyfinAPIClient()
        let store = SavedServersStore()
        let auth = AuthenticationService(apiClient: client, savedServers: store)
        _authService = StateObject(wrappedValue: auth)
        _savedServers = StateObject(wrappedValue: store)
        _appEnv = StateObject(wrappedValue: AppEnvironment(apiClient: client, authService: auth))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app loads in background
                Group {
                    if authService.isAuthenticated {
                        // Keying on (serverURL, userId) forces MainTabView to
                        // remount when the user switches accounts/servers from
                        // Settings. That throws away the prior session's
                        // HomeViewModel / SearchViewModel state — otherwise the
                        // user would see the previous server's shelves bleed
                        // through until each VM was manually reset.
                        MainTabView(env: appEnv, appState: appState)
                            .id(authService.currentSession.map { "\($0.serverURL)|\($0.user.id)" } ?? "anon")
                    } else {
                        // Wrap the unauth gate in a NavigationStack so
                        // ServerEntryView can push LoginView (and from there
                        // QuickConnectView) instead of layering full-screen
                        // covers. Modal covers swallow the Siri Remote Menu
                        // button on tvOS, and nested covers (LoginView →
                        // QuickConnect) don't reliably present — pushes
                        // dismiss naturally on Menu and don't stack-fight.
                        NavigationStack {
                            ServerEntryView()
                        }
                    }
                }

                // Show splash screen overlay while launching
                if appState.isLaunching {
                    SplashScreenView(isActive: $appState.isLaunching)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
        }
        .environmentObject(authService)
        .environmentObject(appEnv)
        .environmentObject(savedServers)
        .environmentObject(appState)
    }
}
