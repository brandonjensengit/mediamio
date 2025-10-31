//
//  Constants.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import SwiftUI

enum Constants {
    // MARK: - API Configuration
    enum API {
        static let clientName = "MediaMio"
        static let clientVersion = "1.0.0"
        static let deviceName = "Apple TV"
        static let deviceId = UUID().uuidString // Should be persisted per device

        // API Endpoints
        enum Endpoints {
            // Authentication
            static let authenticateByName = "/Users/AuthenticateByName"
            static let systemInfo = "/System/Info/Public"
            static let users = "/Users"

            // Content
            static let items = "/Items"
            static func userItems(userId: String) -> String {
                "/Users/\(userId)/Items"
            }
            static func itemDetails(itemId: String) -> String {
                "/Items/\(itemId)"
            }
            static func userItemDetails(userId: String, itemId: String) -> String {
                "/Users/\(userId)/Items/\(itemId)"
            }

            // Libraries
            static func userViews(userId: String) -> String {
                "/Users/\(userId)/Views"
            }

            // Continue Watching
            static func resumeItems(userId: String) -> String {
                "/Users/\(userId)/Items/Resume"
            }

            // Recently Added
            static func latestItems(userId: String) -> String {
                "/Users/\(userId)/Items/Latest"
            }

            // Images
            static func itemImage(itemId: String, imageType: String) -> String {
                "/Items/\(itemId)/Images/\(imageType)"
            }

            // Video Streaming
            static func videoStream(itemId: String) -> String {
                "/Videos/\(itemId)/stream"
            }
            static func hlsStream(itemId: String) -> String {
                "/Videos/\(itemId)/master.m3u8"
            }
        }
    }

    // MARK: - Keychain
    enum Keychain {
        static let service = "com.mediamio.tvos"
        static let serverURLKey = "serverURL"
        static let usernameKey = "username"
        static let accessTokenKey = "accessToken"
        static let userIdKey = "userId"
    }

    // MARK: - UserDefaults
    enum UserDefaultsKeys {
        static let rememberMe = "rememberMe"
        static let lastServerURL = "lastServerURL"
        static let lastUsername = "lastUsername"
        static let deviceId = "deviceId"
    }

    // MARK: - UI Constants
    enum UI {
        // Focus Effects
        static let focusScale: CGFloat = 1.08
        static let normalScale: CGFloat = 1.0
        static let focusShadowRadius: CGFloat = 20
        static let animationDuration: Double = 0.2

        // Spacing
        static let defaultPadding: CGFloat = 40
        static let cardSpacing: CGFloat = 30
        static let rowSpacing: CGFloat = 60
        static let sectionSpacing: CGFloat = 80

        // Poster Sizes
        static let posterWidth: CGFloat = 250
        static let posterHeight: CGFloat = 375
        static let posterAspectRatio: CGFloat = 2.0 / 3.0  // 2:3 for movie posters

        // Backdrop/Thumbnail Sizes
        static let thumbWidth: CGFloat = 400
        static let thumbHeight: CGFloat = 225
        static let backdropAspectRatio: CGFloat = 16.0 / 9.0

        // Hero Banner
        static let heroBannerHeight: CGFloat = 600
        static let heroBannerImageHeight: CGFloat = 700

        // Buttons & Cards
        static let buttonHeight: CGFloat = 80
        static let cornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 8

        // Image Quality
        static let imageQuality: Int = 90
        static let posterImageMaxWidth: Int = 400
        static let backdropImageMaxWidth: Int = 1920
        static let thumbImageMaxWidth: Int = 600
    }

    // MARK: - Colors
    enum Colors {
        static let primary = Color.blue
        static let secondary = Color.gray
        static let background = Color.black
        static let cardBackground = Color(white: 0.15)
        static let focusedBorder = Color.white
    }

    // MARK: - Error Messages
    enum ErrorMessages {
        static let invalidURL = "Please enter a valid server URL"
        static let connectionFailed = "Unable to connect to server"
        static let authenticationFailed = "Invalid username or password"
        static let networkError = "Network error. Please check your connection"
        static let unknownError = "An unknown error occurred"
    }
}
