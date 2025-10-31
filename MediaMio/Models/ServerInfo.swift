//
//  ServerInfo.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

struct ServerInfo: Codable, Identifiable {
    let id: String
    let serverName: String
    let version: String
    let operatingSystem: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case serverName = "ServerName"
        case version = "Version"
        case operatingSystem = "OperatingSystem"
    }
}

struct ServerConfiguration: Codable {
    let url: String
    let name: String?
    let isConnected: Bool

    init(url: String, name: String? = nil, isConnected: Bool = false) {
        self.url = url
        self.name = name
        self.isConnected = isConnected
    }
}
