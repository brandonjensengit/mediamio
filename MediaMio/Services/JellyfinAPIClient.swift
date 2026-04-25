//
//  JellyfinAPIClient.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine
import UIKit

@MainActor
class JellyfinAPIClient: ObservableObject {
    @Published var baseURL: String = ""
    @Published var accessToken: String = ""

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var deviceId: String { DeviceIdentifier.current() }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Reuse up to 4 HTTP/2 streams per host. Jellyfin home loads can fan
        // out 8+ parallel /Items requests; without this, each one negotiates
        // a fresh connection on cold start and tail latency dominates TTFP.
        config.httpMaximumConnectionsPerHost = 4
        // Honor server-side Cache-Control / ETag. Jellyfin sends those on
        // /Items and image endpoints; a tab-back to Home can short-circuit
        // to 304s instead of full re-decodes.
        config.requestCachePolicy = .useProtocolCachePolicy
        // 16MB memory, 64MB on disk. Holds enough JSON to skip repeat
        // library/section fetches on tab-back without bloating the device.
        config.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            directory: nil
        )
        // Block briefly waiting for connectivity instead of erroring out the
        // moment Wi-Fi flickers — covers the "Apple TV briefly drops 5GHz on
        // wake" case where the user would otherwise see a transient failure.
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Configuration
    func configure(baseURL: String, accessToken: String = "") {
        // Normalize URL - remove trailing slash
        var normalizedURL = baseURL.trimmingCharacters(in: .whitespaces)
        if normalizedURL.hasSuffix("/") {
            normalizedURL.removeLast()
        }
        self.baseURL = normalizedURL
        self.accessToken = accessToken
    }

    // MARK: - Request Building
    private func buildURL(endpoint: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard !baseURL.isEmpty else {
            throw APIError.invalidURL
        }

        let urlString = baseURL + endpoint
        guard var components = URLComponents(string: urlString) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        return url
    }

    private func buildRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Mutations (PlayedItems / FavoriteItems POST + DELETE, etc.) must
        // never satisfy from cache — go straight to network so the server
        // sees the write request and returns the fresh UserData.
        if method != "GET" {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Authorization carries token + client identification in one header.
        request.setValue(buildAuthorizationHeader(), forHTTPHeaderField: "X-Emby-Authorization")

        return request
    }

    private func buildAuthorizationHeader() -> String {
        var parts: [String] = []
        parts.append("MediaBrowser Client=\"\(Constants.API.clientName)\"")
        parts.append("Device=\"\(Constants.API.deviceName)\"")
        parts.append("DeviceId=\"\(deviceId)\"")
        parts.append("Version=\"\(Constants.API.clientVersion)\"")

        if !accessToken.isEmpty {
            parts.append("Token=\"\(accessToken)\"")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Generic Request Methods
    func get<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)
        let request = buildRequest(url: url, method: "GET")
        return try await performRequest(request)
    }

    func post<T: Decodable, B: Encodable>(
        endpoint: String,
        body: B? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)

        var bodyData: Data?
        if let body = body {
            bodyData = try encoder.encode(body)
        }

        let request = buildRequest(url: url, method: "POST", body: bodyData)
        return try await performRequest(request)
    }

    func post<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)
        let request = buildRequest(url: url, method: "POST")
        return try await performRequest(request)
    }

    func delete<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint, queryItems: queryItems)
        let request = buildRequest(url: url, method: "DELETE")
        return try await performRequest(request)
    }

    // MARK: - Retry Policy
    // Transient failures (timeouts, lost connections, 5xx) get a capped retry with
    // exponential backoff. Permanent failures (401, 4xx, decoding) surface immediately.
    private static let retryDelaysMs: [UInt64] = [500, 1500, 4000]

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        var lastError: Error = APIError.unknown
        for attempt in 0...Self.retryDelaysMs.count {
            do {
                return try await performSingleRequest(request)
            } catch let error {
                lastError = error
                guard Self.isTransient(error), attempt < Self.retryDelaysMs.count else {
                    throw error
                }
                let delayMs = Self.retryDelaysMs[attempt]
                print("🔁 Transient failure on attempt \(attempt + 1)/\(Self.retryDelaysMs.count + 1): \(error.localizedDescription). Retrying in \(delayMs)ms.")
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
        }
        throw lastError
    }

    private func performSingleRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("🌐 Making request to: \(request.url?.absoluteString ?? "unknown")")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }

            print("📡 Response status code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                print("❌ Authentication failed (401)")
                throw APIError.authenticationFailed
            default:
                print("❌ HTTP error: \(httpResponse.statusCode)")
                throw APIError.httpError(httpResponse.statusCode)
            }

            do {
                let decoded = try decoder.decode(T.self, from: data)
                print("✅ Successfully decoded response")
                return decoded
            } catch {
                print("❌ Decoding error: \(error)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw APIError.decodingError(error)
            }
        } catch let error as URLError {
            print("❌ Network error: \(error.localizedDescription) (code \(error.code.rawValue))")
            throw APIError.networkError(error)
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
    }

    /// A transient failure is one where a retry with the same request has a reasonable
    /// chance of succeeding — network blips, 5xx, DNS hiccups. 4xx (including 401) is
    /// not transient; the client sent something the server rejected deterministically.
    private static func isTransient(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let underlying):
                guard let urlError = underlying as? URLError else { return false }
                switch urlError.code {
                case .timedOut,
                     .networkConnectionLost,
                     .notConnectedToInternet,
                     .dnsLookupFailed,
                     .cannotConnectToHost,
                     .cannotFindHost,
                     .resourceUnavailable:
                    return true
                default:
                    return false
                }
            case .httpError(let code):
                return (500...599).contains(code)
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
                || urlError.code == .networkConnectionLost
                || urlError.code == .notConnectedToInternet
        }
        return false
    }

    // MARK: - Server Info
    func getServerInfo() async throws -> ServerInfo {
        try await get(endpoint: Constants.API.Endpoints.systemInfo)
    }

    func testConnection(serverURL: String) async throws -> ServerInfo {
        // Temporarily configure with the test URL
        let previousURL = self.baseURL
        let previousToken = self.accessToken

        defer {
            self.baseURL = previousURL
            self.accessToken = previousToken
        }

        configure(baseURL: serverURL)
        return try await getServerInfo()
    }

    // MARK: - Authentication
    func authenticate(username: String, password: String) async throws -> AuthenticationResult {
        let authRequest = AuthenticationRequest(username: username, pw: password)

        let result: AuthenticationResult = try await post(
            endpoint: Constants.API.Endpoints.authenticateByName,
            body: authRequest
        )

        // Update client with new token
        self.accessToken = result.accessToken

        return result
    }

    // MARK: - Quick Connect

    /// Ask the server whether Quick Connect is enabled. Returns false if the
    /// endpoint is missing (older Jellyfin) or the server has it disabled.
    func isQuickConnectEnabled() async -> Bool {
        do {
            let enabled: Bool = try await get(endpoint: "/QuickConnect/Enabled")
            return enabled
        } catch {
            print("⚠️ Quick Connect enabled-check failed (treating as disabled): \(error)")
            return false
        }
    }

    /// Start a Quick Connect session. The returned `code` is what the user
    /// types into the Jellyfin web UI; the `secret` is what we poll with.
    func initiateQuickConnect() async throws -> QuickConnectResult {
        try await post(endpoint: "/QuickConnect/Initiate")
    }

    /// Check on a Quick Connect session's status. When `authenticated` flips
    /// to true, call `authenticateWithQuickConnect(secret:)` to trade the
    /// secret for a real access token.
    func checkQuickConnectStatus(secret: String) async throws -> QuickConnectResult {
        let queryItems = [URLQueryItem(name: "secret", value: secret)]
        return try await get(endpoint: "/QuickConnect/Connect", queryItems: queryItems)
    }

    /// Exchange an approved Quick Connect secret for a real `AuthenticationResult`
    /// (access token + user).
    func authenticateWithQuickConnect(secret: String) async throws -> AuthenticationResult {
        let body = QuickConnectAuthenticateRequest(secret: secret)
        return try await post(endpoint: "/Users/AuthenticateWithQuickConnect", body: body)
    }

    // MARK: - User Methods
    func getCurrentUser(userId: String) async throws -> User {
        try await get(endpoint: "/Users/\(userId)")
    }

    // MARK: - Content Methods

    /// Get user's libraries/views (Movies, TV Shows, etc.)
    func getLibraries(userId: String) async throws -> LibrariesResponse {
        let endpoint = Constants.API.Endpoints.userViews(userId: userId)
        return try await get(endpoint: endpoint)
    }

    /// Get continue watching items
    func getContinueWatching(
        userId: String,
        limit: Int = 12,
        maxOfficialRating: String? = nil
    ) async throws -> ItemsResponse {
        // `/Users/{id}/Items/Resume` already filters to unfinished items (it
        // excludes `Played == true` and requires a non-zero playback
        // position). Explicit `SortBy=DatePlayed&SortOrder=Descending`
        // guarantees the most recently watched item is first — some server
        // versions don't apply this sort by default.
        let endpoint = Constants.API.Endpoints.resumeItems(userId: userId)
        var queryItems = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,BasicSyncInfo"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb,Logo"),
            URLQueryItem(name: "EnableTotalRecordCount", value: "false"),
            URLQueryItem(name: "MediaTypes", value: "Video"),
            URLQueryItem(name: "SortBy", value: "DatePlayed"),
            URLQueryItem(name: "SortOrder", value: "Descending")
        ]
        if let maxRating = maxOfficialRating {
            queryItems.append(URLQueryItem(name: "MaxOfficialRating", value: maxRating))
        }
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get recently added items
    func getRecentlyAdded(
        userId: String,
        limit: Int = 16,
        parentId: String? = nil,
        maxOfficialRating: String? = nil
    ) async throws -> [MediaItem] {
        let endpoint = Constants.API.Endpoints.latestItems(userId: userId)
        var queryItems = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,OfficialRating"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb,Logo")
        ]

        if let parentId = parentId {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentId))
        }
        if let maxRating = maxOfficialRating {
            queryItems.append(URLQueryItem(name: "MaxOfficialRating", value: maxRating))
        }

        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get items from a library with filters
    func getLibraryItems(
        userId: String,
        parentId: String? = nil,
        includeItemTypes: [String]? = nil,
        genres: [String]? = nil,
        years: [Int]? = nil,
        minRating: Double? = nil,
        isPlayed: Bool? = nil,
        nameStartsWith: String? = nil,
        maxOfficialRating: String? = nil,
        limit: Int = 50,
        startIndex: Int = 0,
        sortBy: String? = "SortName",
        sortOrder: String? = "Ascending"
    ) async throws -> ItemsResponse {
        let endpoint = Constants.API.Endpoints.userItems(userId: userId)

        var queryItems = [
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview,OfficialRating"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb,Logo"),
            URLQueryItem(name: "StartIndex", value: String(startIndex)),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Recursive", value: "true")
        ]

        if let parentId = parentId {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentId))
        }

        if let types = includeItemTypes {
            queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: types.joined(separator: ",")))
        }

        // Filter: Genres
        if let genres = genres, !genres.isEmpty {
            queryItems.append(URLQueryItem(name: "Genres", value: genres.joined(separator: ",")))
        }

        // Filter: Years
        if let years = years, !years.isEmpty {
            queryItems.append(URLQueryItem(name: "Years", value: years.map(String.init).joined(separator: ",")))
        }

        // Filter: Minimum Rating
        if let minRating = minRating {
            queryItems.append(URLQueryItem(name: "MinCommunityRating", value: String(minRating)))
        }

        // Filter: Played status
        if let isPlayed = isPlayed {
            queryItems.append(URLQueryItem(name: "IsPlayed", value: String(isPlayed)))
        }

        // Filter: Name starts with (letter-jump). Jellyfin treats this as a
        // prefix match on SortName, which is what we want — "S" matches
        // "Spider-Man" and "Stranger Things" but not "Interstellar".
        if let prefix = nameStartsWith, !prefix.isEmpty {
            queryItems.append(URLQueryItem(name: "NameStartsWith", value: prefix))
        }

        // Filter: parental rating ceiling. Server-side; we also re-apply
        // a client-side filter in `ContentService` for defense in depth.
        if let maxRating = maxOfficialRating {
            queryItems.append(URLQueryItem(name: "MaxOfficialRating", value: maxRating))
        }

        if let sortBy = sortBy {
            queryItems.append(URLQueryItem(name: "SortBy", value: sortBy))
        }

        if let sortOrder = sortOrder {
            queryItems.append(URLQueryItem(name: "SortOrder", value: sortOrder))
        }

        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get detailed information about a specific item.
    /// `MediaSources,MediaStreams` are required for the playback URL builder
    /// (codec analysis → Direct Play / Remux / Transcode decision) and for
    /// the Playback Info panel's General / Video / Audio rows. Without them,
    /// the URL builder defaults to forced transcode and the info panel
    /// renders "Video: Unknown" / "Audio: Unknown".
    func getItemDetails(userId: String, itemId: String) async throws -> MediaItem {
        let endpoint = Constants.API.Endpoints.userItemDetails(userId: userId, itemId: itemId)
        let queryItems = [
            URLQueryItem(
                name: "Fields",
                value: "Path,Genres,Studios,People,Overview,ProviderIds,Chapters,MediaSources,MediaStreams"
            )
        ]
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get similar items (recommendations)
    func getSimilarItems(userId: String, itemId: String, limit: Int = 12) async throws -> ItemsResponse {
        let endpoint = "/Items/\(itemId)/Similar"
        let queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview")
        ]
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get seasons for a TV series
    func getSeasons(userId: String, seriesId: String) async throws -> ItemsResponse {
        let endpoint = "/Shows/\(seriesId)/Seasons"
        let queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,ItemCounts")
        ]
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get episodes for a TV series season
    func getEpisodes(userId: String, seriesId: String, seasonId: String) async throws -> ItemsResponse {
        let endpoint = "/Shows/\(seriesId)/Episodes"
        let queryItems = [
            URLQueryItem(name: "UserId", value: userId),
            URLQueryItem(name: "SeasonId", value: seasonId),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview")
        ]
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Search for items
    func searchItems(
        userId: String,
        searchTerm: String,
        includeItemTypes: [String]? = nil,
        maxOfficialRating: String? = nil,
        limit: Int = 50,
        startIndex: Int = 0
    ) async throws -> ItemsResponse {
        let endpoint = "/Users/\(userId)/Items"

        var queryItems = [
            URLQueryItem(name: "SearchTerm", value: searchTerm),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview,OfficialRating"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb,Logo"),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "StartIndex", value: String(startIndex))
        ]

        if let types = includeItemTypes {
            queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: types.joined(separator: ",")))
        }

        if let maxRating = maxOfficialRating {
            queryItems.append(URLQueryItem(name: "MaxOfficialRating", value: maxRating))
        }

        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    // MARK: - User Favorites

    /// Mark an item as favorite. Returns the updated UserData as the server
    /// sees it (use this to refresh local state rather than assuming isFavorite=true).
    func markFavorite(userId: String, itemId: String) async throws -> UserData {
        let endpoint = "/Users/\(userId)/FavoriteItems/\(itemId)"
        return try await post(endpoint: endpoint)
    }

    /// Remove favorite status from an item. Returns the updated UserData.
    func unmarkFavorite(userId: String, itemId: String) async throws -> UserData {
        let endpoint = "/Users/\(userId)/FavoriteItems/\(itemId)"
        return try await delete(endpoint: endpoint)
    }

    // MARK: - User Played State

    /// Mark an item as played (fully watched). Also clears it from the
    /// `/Items/Resume` shelf — Jellyfin has no dedicated "hide from resume"
    /// endpoint, so the Remove-from-Continue-Watching action routes here.
    func markPlayed(userId: String, itemId: String) async throws -> UserData {
        let endpoint = "/Users/\(userId)/PlayedItems/\(itemId)"
        return try await post(endpoint: endpoint)
    }

    /// Clear the played flag from an item.
    func unmarkPlayed(userId: String, itemId: String) async throws -> UserData {
        let endpoint = "/Users/\(userId)/PlayedItems/\(itemId)"
        return try await delete(endpoint: endpoint)
    }

    /// Build image URL for an item
    func buildImageURL(
        itemId: String,
        imageType: String,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        quality: Int = 90
    ) -> String {
        var url = "\(baseURL)/Items/\(itemId)/Images/\(imageType)?quality=\(quality)"

        if let width = maxWidth {
            url += "&maxWidth=\(width)"
        }

        if let height = maxHeight {
            url += "&maxHeight=\(height)"
        }

        return url
    }
}
