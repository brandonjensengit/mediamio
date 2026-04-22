//
//  User.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let hasPassword: Bool
    let hasConfiguredPassword: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case hasConfiguredPassword = "HasConfiguredPassword"
    }
}

struct AuthenticationResult: Codable {
    let user: User
    let accessToken: String
    let serverId: String

    enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

struct AuthenticationRequest: Codable {
    let username: String
    let pw: String

    enum CodingKeys: String, CodingKey {
        case username = "Username"
        case pw = "Pw"
    }
}

struct UserSession {
    let user: User
    let accessToken: String
    let serverURL: String
    let serverId: String

    var isValid: Bool {
        !accessToken.isEmpty && !serverURL.isEmpty
    }
}

// MARK: - Quick Connect

/// Server response from the Quick Connect endpoints.
///
/// The flow: the TV `POST`s to `/QuickConnect/Initiate` and gets back a
/// `Secret` + human-readable `Code`. It shows the code on screen; the user
/// types the code into the Jellyfin web UI on any other device and approves.
/// The TV polls `GET /QuickConnect/Connect?secret=...` until `Authenticated == true`,
/// then trades the secret for a normal access token via
/// `POST /Users/AuthenticateWithQuickConnect`.
struct QuickConnectResult: Codable {
    let secret: String
    let code: String
    let authenticated: Bool
    let deviceId: String?
    let deviceName: String?
    let appName: String?
    let appVersion: String?
    let dateAdded: String?

    enum CodingKeys: String, CodingKey {
        case secret = "Secret"
        case code = "Code"
        case authenticated = "Authenticated"
        case deviceId = "DeviceId"
        case deviceName = "DeviceName"
        case appName = "AppName"
        case appVersion = "AppVersion"
        case dateAdded = "DateAdded"
    }
}

struct QuickConnectAuthenticateRequest: Codable {
    let secret: String

    enum CodingKeys: String, CodingKey {
        case secret = "Secret"
    }
}
