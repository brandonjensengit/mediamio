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

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                ServerEntryView()
            }
        }
        .environmentObject(authService)
    }
}
