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
    @StateObject private var appState = AppState()

    init() {
        let auth = AuthenticationService()
        _authService = StateObject(wrappedValue: auth)
        _appEnv = StateObject(wrappedValue: AppEnvironment(authService: auth))
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
        .environmentObject(appState)
    }
}
