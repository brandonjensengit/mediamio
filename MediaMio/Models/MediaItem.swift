//
//  MediaItem.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

// MARK: - Media Item
struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let overview: String?
    let productionYear: Int?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let imageTags: ImageTags?
    let imageBlurHashes: ImageBlurHashes?
    let userData: UserData?

    // TV Show specific
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let indexNumber: Int?  // Episode number
    let parentIndexNumber: Int?  // Season number

    // Additional metadata
    let premiereDate: String?
    let genres: [String]?
    let studios: [StudioInfo]?
    let people: [PersonInfo]?
    let taglines: [String]?

    // Media sources (for file info)
    let mediaSources: [MediaSource]?

    // Critic rating + external provider IDs / trailer URLs. These are
    // populated by the `/Users/{userId}/Items/{itemId}` details endpoint;
    // list endpoints typically omit them.
    let criticRating: Double?
    let providerIds: [String: String]?
    let externalUrls: [ExternalURL]?
    let remoteTrailers: [RemoteTrailer]?

    // Chapter markers. Populated only when the details request includes
    // `Fields=Chapters`. Each chapter carries a tick-based start offset +
    // optional image tag (rendered as a thumbnail scrubber on Detail).
    let chapters: [Chapter]?

    // Parent image lookups. For Episodes, Jellyfin does not stamp a `Logo`
    // on the episode itself — the series owns the logo. These two fields
    // let us resolve a hero title treatment for featured episodes without
    // an extra API round-trip to `/Items/{seriesId}`.
    let parentLogoItemId: String?
    let parentLogoImageTag: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case userData = "UserData"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case premiereDate = "PremiereDate"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case taglines = "Taglines"
        case mediaSources = "MediaSources"
        case criticRating = "CriticRating"
        case providerIds = "ProviderIds"
        case externalUrls = "ExternalUrls"
        case remoteTrailers = "RemoteTrailers"
        case chapters = "Chapters"
        case parentLogoItemId = "ParentLogoItemId"
        case parentLogoImageTag = "ParentLogoImageTag"
    }

    // MARK: - Computed Properties

    var isMovie: Bool {
        type == "Movie"
    }

    var isSeries: Bool {
        type == "Series"
    }

    var isEpisode: Bool {
        type == "Episode"
    }

    var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        return Int(ticks / 600_000_000) // Convert ticks to minutes
    }

    var runtimeFormatted: String? {
        guard let minutes = runtimeMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    var yearText: String? {
        guard let year = productionYear else { return nil }
        return String(year)
    }

    var ratingText: String? {
        guard let rating = communityRating else { return nil }
        return String(format: "%.1f", rating)
    }

    var episodeText: String? {
        guard isEpisode else { return nil }
        if let season = parentIndexNumber, let episode = indexNumber {
            return "S\(season)E\(episode)"
        }
        return nil
    }

    /// "23m left" / "1h 5m left" for Continue Watching tiles. Returns nil
    /// when no progress exists or when playback is within 1 minute of the
    /// end (avoids "0m left" strings on all-but-finished items).
    var remainingText: String? {
        guard let position = userData?.playbackPositionTicks,
              let total = runTimeTicks,
              total > position else { return nil }
        let remainingMinutes = Int((total - position) / 600_000_000)
        guard remainingMinutes > 0 else { return nil }
        let hours = remainingMinutes / 60
        let mins = remainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m left"
        }
        return "\(mins)m left"
    }

    // MARK: - Image URLs

    func primaryImageURL(baseURL: String, maxWidth: Int = 400, quality: Int = 90) -> String? {
        guard imageTags?.primary != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    func backdropImageURL(baseURL: String, maxWidth: Int = 1920, quality: Int = 90) -> String? {
        guard imageTags?.backdrop != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Backdrop?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    func thumbImageURL(baseURL: String, maxWidth: Int = 600, quality: Int = 90) -> String? {
        guard imageTags?.thumb != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Thumb?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    /// Title-treatment logo (transparent PNG with the title styled). Populated
    /// from Jellyfin's `ImageTags.Logo` — for TMDb-scraped instances this
    /// resolves for most movies and shows, and renders as the hero headline
    /// instead of plain text. For Episodes, the logo lives on the parent
    /// series, so this helper falls back to `ParentLogoItemId` when the
    /// item has no direct logo of its own.
    func logoImageURL(baseURL: String, maxWidth: Int = 600, quality: Int = 90) -> String? {
        if imageTags?.logo != nil {
            return "\(baseURL)/Items/\(id)/Images/Logo?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        if let parentId = parentLogoItemId, parentLogoImageTag != nil {
            return "\(baseURL)/Items/\(parentId)/Images/Logo?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        return nil
    }

    /// Best 2:3 poster image for a hero keyart slot. For Episodes, `Primary`
    /// is the 16:9 still (wrong aspect) — fall back to the parent series'
    /// `Primary`, which is the show's 2:3 poster. Returns nil when nothing
    /// suitable exists; the caller should render a text fallback then.
    func heroPosterImageURL(baseURL: String, maxWidth: Int = 400, quality: Int = 90) -> String? {
        if isEpisode, let parentId = seriesId {
            return "\(baseURL)/Items/\(parentId)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        return primaryImageURL(baseURL: baseURL, maxWidth: maxWidth, quality: quality)
    }

    /// Best 16:9 backdrop for the Detail-page hero. Jellyfin doesn't put
    /// backdrops on Episodes (they live on the parent series), and some
    /// Movies ship without one entirely. Cascades: own Backdrop → own Thumb
    /// → Episode's parent-series Backdrop → parent-series Thumb →
    /// Episode's own `Primary` (the 16:9 still, last resort). Returns nil
    /// only when *nothing* landscape is available.
    func heroBackdropImageURL(baseURL: String, maxWidth: Int = 1920, quality: Int = 90) -> String? {
        if let url = backdropImageURL(baseURL: baseURL, maxWidth: maxWidth, quality: quality) {
            return url
        }
        if let url = thumbImageURL(baseURL: baseURL, maxWidth: maxWidth, quality: quality) {
            return url
        }
        if isEpisode, let parentId = seriesId {
            return "\(baseURL)/Items/\(parentId)/Images/Backdrop?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        if isEpisode, imageTags?.primary != nil {
            return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        return nil
    }

    /// Best 16:9 landscape image for a "Continue Watching"-style tile.
    /// Jellyfin is asymmetric: for an Episode, `Primary` IS the 16:9 still;
    /// for a Movie/Series, `Primary` is a 2:3 poster and the 16:9 frame
    /// lives on `Thumb` or `Backdrop`. Falls back to `Primary` only when
    /// nothing landscape is available (the card will letterbox-crop).
    func landscapeImageURL(baseURL: String, maxWidth: Int = 600, quality: Int = 90) -> String? {
        if isEpisode, imageTags?.primary != nil {
            return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        if imageTags?.thumb != nil {
            return "\(baseURL)/Items/\(id)/Images/Thumb?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        if imageTags?.backdrop != nil {
            return "\(baseURL)/Items/\(id)/Images/Backdrop?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        if imageTags?.primary != nil {
            return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
        }
        return nil
    }

    /// Jellyfin chapter thumbnails are addressable by chapter index, not by
    /// `imageTag` — the tag just signals that an image exists.
    func chapterImageURL(
        baseURL: String,
        chapterIndex: Int,
        maxWidth: Int = 400,
        quality: Int = 85
    ) -> String {
        "\(baseURL)/Items/\(id)/Images/Chapter/\(chapterIndex)?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    // MARK: - Subtitle Helpers

    /// Get all subtitle streams from the media sources
    var subtitleStreams: [MediaStream] {
        guard let mediaSources = mediaSources,
              let firstSource = mediaSources.first,
              let streams = firstSource.mediaStreams else {
            return []
        }
        return streams.filter { $0.type?.lowercased() == "subtitle" }
    }

    /// Get the first subtitle stream index (for SubtitleStreamIndex parameter)
    var firstSubtitleIndex: Int? {
        return subtitleStreams.first?.index
    }

    /// Check if this item has any subtitle tracks
    var hasSubtitles: Bool {
        return !subtitleStreams.isEmpty
    }
}

// MARK: - User Data
struct UserData: Codable, Hashable {
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let isFavorite: Bool?
    let played: Bool?
    let key: String?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case key = "Key"
    }

    var playedPercentage: Double {
        // Note: This will be calculated with runtime when displaying
        0.0
    }

    func playedPercentage(totalTicks: Int64?) -> Double {
        guard let position = playbackPositionTicks,
              let total = totalTicks,
              total > 0 else {
            return 0.0
        }
        return Double(position) / Double(total) * 100.0
    }
}

// MARK: - Image Tags
struct ImageTags: Codable, Hashable {
    let primary: String?
    let backdrop: String?
    let thumb: String?
    let logo: String?
    let banner: String?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case banner = "Banner"
    }
}

// MARK: - Image Blur Hashes
struct ImageBlurHashes: Codable, Hashable {
    let primary: [String: String]?
    let backdrop: [String: String]?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
    }
}

// MARK: - Studio Info
struct StudioInfo: Codable, Hashable {
    let name: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

// MARK: - External URL (IMDb, TMDB, RT, TVDB, …)
struct ExternalURL: Codable, Hashable, Identifiable {
    let name: String
    let url: String

    var id: String { "\(name)\t\(url)" }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case url = "Url"
    }
}

// MARK: - Chapter
struct Chapter: Codable, Hashable, Identifiable {
    let name: String?
    let startPositionTicks: Int64
    let imageTag: String?
    let imageDateModified: String?

    // Chapters don't have a natural ID in the Jellyfin response; the start
    // tick is unique within an item so it doubles as a stable identifier.
    var id: Int64 { startPositionTicks }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case startPositionTicks = "StartPositionTicks"
        case imageTag = "ImageTag"
        case imageDateModified = "ImageDateModified"
    }

    var startSeconds: Double {
        Double(startPositionTicks) / 10_000_000.0
    }

    /// Format as MM:SS or H:MM:SS for display in the chapter strip.
    var formattedStart: String {
        let total = Int(startSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var displayName: String {
        if let name = name, !name.isEmpty { return name }
        return formattedStart
    }
}

// MARK: - Remote Trailer
struct RemoteTrailer: Codable, Hashable, Identifiable {
    let name: String?
    let url: String

    var id: String { url }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case url = "Url"
    }
}

// MARK: - Person Info
struct PersonInfo: Codable, Hashable {
    let name: String
    let id: String?
    let role: String?
    let type: String?
    let primaryImageTag: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
        case primaryImageTag = "PrimaryImageTag"
    }
}

// MARK: - Media Source
struct MediaSource: Codable, Hashable {
    let id: String?
    let name: String?
    let size: Int64?  // File size in bytes
    let container: String?
    let bitrate: Int?
    let mediaStreams: [MediaStream]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case size = "Size"
        case container = "Container"
        case bitrate = "Bitrate"
        case mediaStreams = "MediaStreams"
    }
}

// MARK: - Media Stream
struct MediaStream: Codable, Hashable {
    let index: Int?  // Stream index (used for SubtitleStreamIndex)
    let type: String?  // "Video", "Audio", "Subtitle"
    let codec: String?
    let profile: String?  // "High", "Main 10" — codec profile (video)
    let width: Int?
    let height: Int?
    let bitRate: Int?
    let language: String?
    let displayTitle: String?  // Display name for the stream
    let title: String?  // Title metadata
    let isExternal: Bool?  // True if subtitle file is external (SRT, etc)
    let isDefault: Bool?  // True if this is the default stream
    // Audio-specific
    let channels: Int?  // Channel count (2, 6, 8)
    let channelLayout: String?  // "stereo", "5.1", "7.1"
    let sampleRate: Int?  // Audio sample rate in Hz
    // Video-specific — HDR / color range
    let videoRange: String?  // "SDR" | "HDR" (legacy Jellyfin field)
    let videoRangeType: String?  // "SDR" | "HDR10" | "HDR10Plus" | "DOVI" | "DOVIWithHDR10"

    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case type = "Type"
        case codec = "Codec"
        case profile = "Profile"
        case width = "Width"
        case height = "Height"
        case bitRate = "BitRate"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case title = "Title"
        case isExternal = "IsExternal"
        case isDefault = "IsDefault"
        case channels = "Channels"
        case channelLayout = "ChannelLayout"
        case sampleRate = "SampleRate"
        case videoRange = "VideoRange"
        case videoRangeType = "VideoRangeType"
    }

    // Helper computed property for subtitle display name
    var subtitleDisplayName: String {
        if let title = displayTitle, !title.isEmpty {
            return title
        }
        if let title = title, !title.isEmpty {
            return title
        }
        if let lang = language, !lang.isEmpty {
            return lang.uppercased()
        }
        return "Unknown"
    }
}

// MARK: - Items Response
struct ItemsResponse: Codable {
    let items: [MediaItem]
    let totalRecordCount: Int?
    let startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
