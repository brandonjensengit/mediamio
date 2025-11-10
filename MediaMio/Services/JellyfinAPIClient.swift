//
//  JellyfinAPIClient.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation
import Combine

@MainActor
class JellyfinAPIClient: ObservableObject {
    @Published var baseURL: String = ""
    @Published var accessToken: String = ""

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // Device ID - should be consistent per device
    private var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.deviceId) {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Constants.UserDefaultsKeys.deviceId)
        return newId
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
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

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add authentication header if token exists
        if !accessToken.isEmpty {
            request.setValue("MediaBrowser Token=\"\(accessToken)\"", forHTTPHeaderField: "X-Emby-Authorization")
        }

        // Add client identification
        let authHeader = buildAuthorizationHeader()
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")

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

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("🌐 Making request to: \(request.url?.absoluteString ?? "unknown")")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw APIError.invalidResponse
            }

            print("📡 Response status code: \(httpResponse.statusCode)")

            // Handle HTTP errors
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

            // Decode response
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
            print("❌ Network error: \(error.localizedDescription)")
            print("   Error code: \(error.code.rawValue)")
            throw APIError.networkError(error)
        } catch {
            print("❌ Unknown error: \(error)")
            throw error
        }
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
    func getContinueWatching(userId: String, limit: Int = 12) async throws -> ItemsResponse {
        let endpoint = Constants.API.Endpoints.resumeItems(userId: userId)
        let queryItems = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,BasicSyncInfo"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
            URLQueryItem(name: "EnableTotalRecordCount", value: "false"),
            URLQueryItem(name: "MediaTypes", value: "Video")
        ]
        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get recently added items
    func getRecentlyAdded(userId: String, limit: Int = 16, parentId: String? = nil) async throws -> [MediaItem] {
        let endpoint = Constants.API.Endpoints.latestItems(userId: userId)
        var queryItems = [
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb")
        ]

        if let parentId = parentId {
            queryItems.append(URLQueryItem(name: "ParentId", value: parentId))
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
        limit: Int = 50,
        startIndex: Int = 0,
        sortBy: String? = "SortName",
        sortOrder: String? = "Ascending"
    ) async throws -> ItemsResponse {
        let endpoint = Constants.API.Endpoints.userItems(userId: userId)

        var queryItems = [
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
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

        if let sortBy = sortBy {
            queryItems.append(URLQueryItem(name: "SortBy", value: sortBy))
        }

        if let sortOrder = sortOrder {
            queryItems.append(URLQueryItem(name: "SortOrder", value: sortOrder))
        }

        return try await get(endpoint: endpoint, queryItems: queryItems)
    }

    /// Get detailed information about a specific item
    func getItemDetails(userId: String, itemId: String) async throws -> MediaItem {
        let endpoint = Constants.API.Endpoints.userItemDetails(userId: userId, itemId: itemId)
        let queryItems = [
            URLQueryItem(name: "Fields", value: "Path,Genres,Studios,People,Overview,ProviderIds")
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
        limit: Int = 50,
        startIndex: Int = 0
    ) async throws -> ItemsResponse {
        let endpoint = "/Users/\(userId)/Items"

        var queryItems = [
            URLQueryItem(name: "SearchTerm", value: searchTerm),
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "Fields", value: "PrimaryImageAspectRatio,Path,Overview"),
            URLQueryItem(name: "ImageTypeLimit", value: "1"),
            URLQueryItem(name: "EnableImageTypes", value: "Primary,Backdrop,Thumb"),
            URLQueryItem(name: "Limit", value: String(limit)),
            URLQueryItem(name: "StartIndex", value: String(startIndex))
        ]

        if let types = includeItemTypes {
            queryItems.append(URLQueryItem(name: "IncludeItemTypes", value: types.joined(separator: ",")))
        }

        return try await get(endpoint: endpoint, queryItems: queryItems)
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
