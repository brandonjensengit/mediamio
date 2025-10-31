//
//  MediaMioApp.swift
//  MediaMio
//
//  Created by Brandon Jensen on 10/31/25.
//

import SwiftUI

@main
struct MediaMioApp: App {
    @StateObject private var authService = AuthenticationService()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                HomeView()
            } else {
                ServerEntryView()
            }
        }
        .environmentObject(authService)
    }
}
