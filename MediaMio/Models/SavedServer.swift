//
//  SavedServer.swift
//  MediaMio
//
//  Persistent record of a Jellyfin server the user has previously logged in
//  to, plus every user that's signed in on it. Drives the "pick where you
//  left off" UI on the server-entry screen — a saved server+user pair can
//  become a silent re-login when the stored token is still valid.
//
//  Constraint: this model holds NO secrets. Access tokens live in the
//  Keychain, keyed per (serverURL, userId). A `SavedUser` is a pointer to
//  a token, not the token itself.
//

import Foundation

struct SavedUser: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var lastUsedAt: Date
}

struct SavedServer: Codable, Identifiable, Hashable {
    /// Normalized URL doubles as the stable identity. `serverId` from the
    /// Jellyfin /System/Info response would be nicer but can be missing on
    /// older servers and is unavailable before the first successful login.
    let url: String
    var name: String
    var users: [SavedUser]
    var lastUsedAt: Date

    var id: String { url }

    /// Most-recently-used user, used to auto-select a profile when the
    /// server card is tapped and there's only one reasonable default.
    var primaryUser: SavedUser? {
        users.max(by: { $0.lastUsedAt < $1.lastUsedAt })
    }
}
