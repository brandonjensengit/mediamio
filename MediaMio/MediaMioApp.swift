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
    @StateObject private var authService = AuthenticationService()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app loads in background
                Group {
                    if authService.isAuthenticated {
                        MainTabView()
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
        .environmentObject(appState)
    }
}
