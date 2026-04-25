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

    // `apiClient` is required so the "exactly one client at init time"
    // contract from the perf audit holds. The auth flow methods (`login`,
    // `restoreSession`, `signInWithSavedToken`, `clearSession`) all call
    // `apiClient.configure(...)` directly, so this object does not need a
    // Combine bridge mirroring `$currentSession` onto the client.
    init(apiClient: JellyfinAPIClient, authService: AuthenticationService) {
        self.authService = authService
        self.apiClient = apiClient
        self.contentService = ContentService(apiClient: apiClient, authService: authService)
    }
}
