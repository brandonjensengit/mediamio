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
