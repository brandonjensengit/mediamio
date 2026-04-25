//
//  AppEnvironment.swift
//  MediaMio
//
//  Single object that owns the shared services every screen needs:
//  `apiClient`, `contentService`, `authService`. Built once at the app root
//  and injected as an `@EnvironmentObject`, so no view has to assemble its
//  own Jellyfin client or copy the current session into one.
//
//  Constraint: does NOT own per-screen view models or navigation state.
//  Those belong to the views that present them. This object is only for
//  long-lived, cross-screen services.
//

import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let apiClient: JellyfinAPIClient
    let contentService: ContentService
    let authService: AuthenticationService

    // `apiClient` defaults to nil (fresh-instance fallback) so SwiftUI
    // Previews keep working. Production injects the same instance that
    // `AuthenticationService` was built with — the auth flow methods
    // (`login`, `restoreSession`, `signInWithSavedToken`, `clearSession`)
    // call `apiClient.configure(...)` directly, so this object no longer
    // needs a Combine bridge mirroring `$currentSession` onto the client.
    init(apiClient: JellyfinAPIClient? = nil, authService: AuthenticationService) {
        self.authService = authService
        let client = apiClient ?? JellyfinAPIClient()
        self.apiClient = client
        self.contentService = ContentService(apiClient: client, authService: authService)
    }
}
