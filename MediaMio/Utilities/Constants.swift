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

        /// Per-user token account-key prefix. Composite key format is
        /// `"token:\(serverURL):\(userId)"`, which turns Keychain into a
        /// sparse map from (server, user) → access token while keeping the
        /// single-blob legacy keys above for back-compat restore.
        static let perUserTokenPrefix = "token:"

        /// Parental controls PIN. Separate slot so rotating the PIN doesn't
        /// disturb any other credential.
        static let parentalPINKey = "parentalControlsPIN"
    }

    // MARK: - UserDefaults
    enum UserDefaultsKeys {
        static let rememberMe = "rememberMe"
        static let lastServerURL = "lastServerURL"
        static let lastUsername = "lastUsername"
        static let deviceId = "deviceId"
        static let recentSearches = "recentSearches"
        static let savedServers = "savedServers"
    }

    // MARK: - UI Constants
    enum UI {
        // ── Focus tiers ──────────────────────────────────────────
        /// Chrome surfaces: nav chips, settings rows, toolbar pills, sidebar
        /// rows. Subtle lift, no glow — never competes with content.
        enum ChromeFocus {
            static let scale: CGFloat = 1.03
            static let yOffset: CGFloat = -4
            static let shadowColor: Color = .black.opacity(0.35)
            static let shadowRadius: CGFloat = 10
            static let shadowY: CGFloat = 6
            static let animation: Animation = .easeInOut(duration: 0.2)
        }

        /// Content surfaces: posters, hero CTAs. Bigger lift + dark drop
        /// shadow that reads as depth on a dark background. Never white
        /// glow — that's the AI-generated tell.
        enum ContentFocus {
            static let scale: CGFloat = 1.10
            static let yOffset: CGFloat = -8
            static let shadowColor: Color = .black.opacity(0.55)
            static let shadowRadius: CGFloat = 24
            static let shadowY: CGFloat = 12
            static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.7)
        }

        // Spacing (Netflix-level: 60pt edge padding)
        static let defaultPadding: CGFloat = 60  // Edge breathing room
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
    /// Cinematic palette: warm-amber accent on a cool dark blue-black base.
    /// Source values authored in OKLCH (perceptually even L ramp at fixed
    /// hue 260°, chroma 0.015) and pre-converted to sRGB hex below.
    /// Re-derive in any OKLCH-aware tool if shades need tuning.
    enum Colors {
        // ── Brand accent ──────────────────────────────────────────
        /// Warm amber — projector-tungsten warmth. oklch(0.78 0.15 75)
        static let accent = Color(hex: "e8a13b")
        /// Darker amber for pressed/secondary accent. oklch(0.65 0.13 75)
        static let accentMuted = Color(hex: "b97d22")

        // ── Surfaces (cool dark, never pure black) ────────────────
        /// Page background. oklch(0.15 0.015 260)
        static let background = Color(hex: "0d0f15")
        /// Card / list-row fill. oklch(0.20 0.015 260)
        static let surface1 = Color(hex: "161922")
        /// Pill / secondary-button fill. oklch(0.25 0.015 260)
        static let surface2 = Color(hex: "1f2330")
        /// Focused-chip / elevated fill. oklch(0.32 0.015 260)
        static let surface3 = Color(hex: "2c303f")

        // ── Lines & focus ─────────────────────────────────────────
        /// Hairline divider. surface3 @ 0.6
        static let divider = Color(hex: "2c303f").opacity(0.6)
        /// Default focused-border tint (chrome focus, not glow).
        static let focusedBorder = Color.white

        // ── Legacy aliases (do not use in new code) ───────────────
        /// Use `accent` instead.
        static let primary = accent
        /// Generic muted-text. Prefer `.white.opacity(0.7)` inline.
        static let secondary = Color.gray
        /// Use `surface1` instead.
        static let cardBackground = surface1
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
