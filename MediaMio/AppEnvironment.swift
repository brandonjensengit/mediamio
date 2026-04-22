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

    private var cancellables: Set<AnyCancellable> = []

    init(authService: AuthenticationService) {
        self.authService = authService
        let client = JellyfinAPIClient()
        self.apiClient = client
        self.contentService = ContentService(apiClient: client, authService: authService)

        // The `apiClient`'s `baseURL` + `accessToken` are a mirror of the
        // current session. Subscribing keeps them in sync across login,
        // logout, and server switch — previously every view site rebuilt
        // a fresh `JellyfinAPIClient` and copied these fields by hand.
        authService.$currentSession
            .sink { [weak client] session in
                client?.baseURL = session?.serverURL ?? ""
                client?.accessToken = session?.accessToken ?? ""
            }
            .store(in: &cancellables)
    }
}
