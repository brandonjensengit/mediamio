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
                        MainTabView(env: appEnv, appState: appState)
                    } else {
                        ServerEntryView()
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
