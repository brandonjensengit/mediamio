//
//  ItemDetailView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct ItemDetailView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Backdrop Header
                    DetailHeaderView(viewModel: viewModel)

                    // Content
                    VStack(alignment: .leading, spacing: 50) {
                        let displayItem = viewModel.detailedItem ?? viewModel.item

                        // TV Show Episode Info (if applicable)
                        if displayItem.type == "Episode" {
                            TVShowEpisodeInfoView(item: displayItem)
                        }

                        // TV Show Seasons & Episodes (if Series)
                        if displayItem.type == "Series" {
                            TVShowSeasonsView(viewModel: viewModel)
                        }

                        // Overview
                        if let overview = displayItem.overview {
                            DetailSectionView(title: "Overview") {
                                Text(overview)
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(4)
                                    .padding(.horizontal, Constants.UI.defaultPadding)
                            }
                        }

                        // Metadata
                        DetailMetadataView(viewModel: viewModel)

                        // Ratings & External Links
                        ExternalLinksSection(
                            links: displayItem.externalUrls ?? [],
                            communityRating: displayItem.communityRating,
                            criticRating: displayItem.criticRating
                        )

                        // Chapters (movies only — series/episode chapters live
                        // on the playback side, not worth showing on Detail)
                        if displayItem.type != "Series" {
                            ChaptersSection(
                                item: displayItem,
                                baseURL: viewModel.baseURL
                            ) { chapter in
                                viewModel.playChapter(chapter)
                            }
                        }

                        // Trailers
                        if let trailers = displayItem.remoteTrailers, !trailers.isEmpty {
                            TrailersSection(trailers: trailers)
                        }

                        // Cast & Crew
                        if let people = displayItem.people, !people.isEmpty {
                            CastCrewSection(people: people, baseURL: viewModel.baseURL)
                        }

                        // Similar Items
                        if !viewModel.similarItems.isEmpty {
                            DetailSectionView(title: "More Like This") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 30) {
                                        ForEach(viewModel.similarItems) { item in
                                            PosterCard(
                                                item: item,
                                                baseURL: viewModel.baseURL
                                            ) {
                                                viewModel.selectSimilarItem(item)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Constants.UI.defaultPadding)
                                }
                            }
                        }
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 80)
                }
            }
            .id(viewModel.item.id)  // Force ScrollView to recreate at position 0
            // Push the cinematic header past tvOS overscan margins on the
            // sides and top so the backdrop/gradient bleed to the screen
            // edges. Bottom safe area is preserved so the last scroll
            // section ends with natural breathing room.
            .ignoresSafeArea(edges: [.horizontal, .top])
        }
        .task {
            await viewModel.loadDetails()
        }
    }
}

// MARK: - Detail Header

/// Apple-TV-style cinematic header: full-bleed backdrop, poster on the left,
/// title/metadata/actions stacked to its right. When no real backdrop image
/// exists (Jellyfin returns nothing for many catalog entries) we fall through
/// to a solid surface so the poster carries the visual weight rather than
/// reusing the poster as a centered "logo on a void".
struct DetailHeaderView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    @State private var backdropURL: String?
    @State private var posterURL: String?
    @State private var showPlayChoice: Bool = false
    @FocusState private var focusedButton: FocusableButton?

    enum FocusableButton {
        case play
        case favorite
    }

    private static let headerHeight: CGFloat = 900
    private static let posterWidth: CGFloat = 320
    private static let posterHeight: CGFloat = 480
    private static let horizontalPadding: CGFloat = 80
    private static let bottomPadding: CGFloat = 70
    private static let posterInfoGap: CGFloat = 50

    var body: some View {
        let displayItem = viewModel.detailedItem ?? viewModel.item
        let isEpisode = displayItem.type == "Episode"
        let showPoster = !isEpisode && posterURL != nil

        ZStack(alignment: .bottomLeading) {
            backdropLayer
            gradientLayer
            contentRow(displayItem: displayItem, showPoster: showPoster)
        }
        .frame(height: Self.headerHeight)
        .onAppear {
            updateImageURLs()
            focusedButton = .play
        }
        .onChange(of: viewModel.detailedItem) { _ in
            updateImageURLs()
        }
        .confirmationDialog(
            "Continue Watching",
            isPresented: $showPlayChoice,
            titleVisibility: .visible
        ) {
            Button(resumeButtonTitle) { viewModel.playItem() }
            Button("Play from Beginning") { viewModel.playItem(fromBeginning: true) }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var backdropLayer: some View {
        if let url = backdropURL {
            // Real backdrop — render full-bleed cinematic still.
            GeometryReader { geometry in
                AsyncImageView(
                    url: url,
                    contentMode: .fill,
                    targetPixelSize: ImageSizing.pixelSize(
                        points: CGSize(width: geometry.size.width, height: Self.headerHeight)
                    )
                )
                .frame(width: geometry.size.width, height: Self.headerHeight)
                .clipped()
            }
            .frame(height: Self.headerHeight)
        } else if let url = posterURL {
            // No backdrop in Jellyfin for this item — use the poster as a
            // heavily blurred ambient backdrop so the header still has
            // color and mood. The crisp poster on the left of the content
            // row remains the visual anchor.
            GeometryReader { geometry in
                AsyncImageView(
                    url: url,
                    contentMode: .fill,
                    targetPixelSize: ImageSizing.pixelSize(
                        points: CGSize(width: geometry.size.width / 4, height: Self.headerHeight / 4)
                    )
                )
                .frame(width: geometry.size.width, height: Self.headerHeight)
                .clipped()
                .blur(radius: 80)
                .scaleEffect(1.2)  // Hides the soft-edge artifact at the blur boundary
                .opacity(0.7)
            }
            .frame(height: Self.headerHeight)
            .clipped()
        } else {
            Constants.Colors.surface1
                .frame(height: Self.headerHeight)
        }
    }

    private var gradientLayer: some View {
        LinearGradient(
            colors: [
                .clear,
                .black.opacity(0.25),
                .black.opacity(0.65),
                .black.opacity(0.92),
                Constants.Colors.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Self.headerHeight)
    }

    private func contentRow(displayItem: MediaItem, showPoster: Bool) -> some View {
        HStack(alignment: .bottom, spacing: Self.posterInfoGap) {
            if showPoster, let url = posterURL {
                AsyncImageView(
                    url: url,
                    contentMode: .fill,
                    targetPixelSize: ImageSizing.pixelSize(
                        points: CGSize(width: Self.posterWidth, height: Self.posterHeight)
                    )
                )
                .frame(width: Self.posterWidth, height: Self.posterHeight)
                .clipped()
                .cornerRadius(Constants.UI.cornerRadius)
                .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 12)
            }

            infoColumn(displayItem: displayItem)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.bottom, Self.bottomPadding)
    }

    private func infoColumn(displayItem: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(displayItem.name)
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.6), radius: 12)

            if let line = metadataLine(for: displayItem) {
                Text(line)
                    .font(.title2.weight(.medium))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 8)
            }

            if viewModel.hasProgress {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(viewModel.progressPercentage))% watched")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.75))

                    ProgressBar(progress: viewModel.progressPercentage / 100.0)
                        .frame(height: 6)
                        .frame(maxWidth: 700)
                }
            }

            if displayItem.type != "Series" {
                HStack(spacing: 40) {
                    DetailActionButton(
                        title: "Play",
                        icon: "play.fill",
                        style: .primary
                    ) {
                        if viewModel.hasProgress {
                            showPlayChoice = true
                        } else {
                            viewModel.playItem()
                        }
                    }
                    .focused($focusedButton, equals: .play)

                    DetailActionButton(
                        title: viewModel.isFavorite ? "Unfavorite" : "Favorite",
                        icon: viewModel.isFavorite ? "heart.fill" : "heart",
                        style: .secondary
                    ) {
                        viewModel.toggleFavorite()
                    }
                    .focused($focusedButton, equals: .favorite)
                }
            }
        }
    }

    /// "2026 · PG-13 · 1h 38m · ★ 7.5" — same single-line treatment HeroBanner uses.
    private func metadataLine(for item: MediaItem) -> String? {
        var parts: [String] = []
        if let year = item.yearText { parts.append(year) }
        if let officialRating = item.officialRating, !officialRating.isEmpty {
            parts.append(officialRating)
        }
        if let runtime = item.runtimeFormatted { parts.append(runtime) }
        if let rating = item.ratingText { parts.append("★ \(rating)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Resume from 1h 20m" when a position label is available, else "Resume".
    private var resumeButtonTitle: String {
        if let label = viewModel.resumePositionLabel {
            return "Resume from \(label)"
        }
        return "Resume"
    }

    /// Backdrop is intentionally NOT falling back to primaryImageURL anymore —
    /// using the poster as a centered "backdrop" is what produced the cramped
    /// "logo on a void" look. Empty backdrop now resolves to surface1 and the
    /// poster column carries the identity instead.
    private func updateImageURLs() {
        let displayItem = viewModel.detailedItem ?? viewModel.item

        backdropURL = displayItem.backdropImageURL(
            baseURL: viewModel.baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
            quality: Constants.UI.imageQuality
        )

        posterURL = displayItem.primaryImageURL(
            baseURL: viewModel.baseURL,
            maxWidth: 600,
            quality: Constants.UI.imageQuality
        )
    }
}

// MARK: - Detail Section

struct DetailSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, Constants.UI.defaultPadding)

            content()
        }
    }
}

// MARK: - Metadata Section

struct DetailMetadataView: View {
    @ObservedObject var viewModel: ItemDetailViewModel

    var body: some View {
        let displayItem = viewModel.detailedItem ?? viewModel.item

        return DetailSectionView(title: "Details") {
            VStack(alignment: .leading, spacing: 16) {
                // Genres
                if let genres = displayItem.genres, !genres.isEmpty {
                    MetadataRow(label: "Genres", value: genres.joined(separator: ", "))
                }

                // Studios
                if let studios = displayItem.studios, !studios.isEmpty {
                    MetadataRow(label: "Studio", value: studios.map { $0.name }.joined(separator: ", "))
                }

                // Release Date
                if let premiereString = displayItem.premiereDate,
                   let premiereDate = ISO8601DateFormatter().date(from: premiereString) {
                    MetadataRow(label: "Release Date", value: formatDate(premiereDate))
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Text(label)
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 180, alignment: .leading)

            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - TV Show Episode Info

struct TVShowEpisodeInfoView: View {
    let item: MediaItem

    var body: some View {
        DetailSectionView(title: "Episode Information") {
            VStack(alignment: .leading, spacing: 16) {
                // Series Name
                if let seriesName = item.seriesName {
                    MetadataRow(label: "Series", value: seriesName)
                }

                // Season & Episode
                HStack(spacing: 40) {
                    if let seasonNum = item.parentIndexNumber {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Season")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(seasonNum)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    if let episodeNum = item.indexNumber {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Episode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(episodeNum)")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
    }
}

// MARK: - Action Button

struct DetailActionButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary

        var backgroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return Constants.Colors.surface2
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return Constants.Colors.background
            case .secondary: return .white
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(DetailActionButtonStyle(
            backgroundColor: style.backgroundColor,
            foregroundColor: style.foregroundColor
        ))
        // Belt-and-suspenders against the tvOS system focus halo.
        // .buttonStyle(.plain) + .focusEffectDisabled() alone did NOT
        // remove the white pill underneath — verified in simulator. A
        // custom ButtonStyle is what actually suppresses it because we
        // own the entire rendering chain.
        .focusEffectDisabled()
    }
}

/// Custom ButtonStyle owns the entire visual chain — no system halo can
/// stack underneath. The same `RoundedRectangle` value drives both the
/// background fill and the focus stroke so the shapes literally cannot
/// drift apart.
///
/// Non-private so the link pills + any other Detail surface can opt into
/// the same treatment (one focus language across the whole screen).
struct DetailActionButtonStyle: SwiftUI.ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    var minWidth: CGFloat = 220
    var horizontalPadding: CGFloat = 32
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        DetailActionButtonStyleBody(
            configuration: configuration,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            minWidth: minWidth,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }
}

/// Wrapped in a separate View struct so `@Environment(\.isFocused)` is
/// read in the right context — the value flows in from the focus engine
/// when this view is the label of a focused Button.
struct DetailActionButtonStyleBody: View {
    let configuration: SwiftUI.ButtonStyle.Configuration
    let backgroundColor: Color
    let foregroundColor: Color
    let minWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    @Environment(\.isFocused) private var isFocused

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius, style: .continuous)
    }

    var body: some View {
        configuration.label
            .frame(minWidth: minWidth)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor, in: shape)
            .overlay(
                shape.strokeBorder(Constants.Colors.accent, lineWidth: 4)
                    .opacity(isFocused ? 1 : 0)
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - TV Show Seasons View

struct TVShowSeasonsView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    @FocusState private var focusedEpisode: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Season Selector
            if !viewModel.seasons.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(viewModel.seasons) { season in
                            SeasonButton(
                                season: season,
                                isSelected: viewModel.selectedSeason?.id == season.id
                            ) {
                                Task {
                                    await viewModel.selectSeason(season)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }

            // Episodes List
            if !viewModel.episodes.isEmpty {
                DetailSectionView(title: viewModel.selectedSeason?.name ?? "Episodes") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 30) {
                            ForEach(viewModel.episodes) { episode in
                                EpisodeCard(
                                    episode: episode,
                                    baseURL: viewModel.baseURL
                                ) {
                                    viewModel.playEpisode(episode)
                                }
                                .focused($focusedEpisode, equals: episode.id)
                            }
                        }
                        .padding(.horizontal, Constants.UI.defaultPadding)
                    }
                }
            }
        }
    }
}

struct SeasonButton: View {
    let season: MediaItem
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            Text(season.name)
                .font(.title3)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? Constants.Colors.background : .white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(isSelected ? Constants.Colors.accent : Constants.Colors.surface2)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .chromeFocus(isFocused: isFocused)
    }
}

struct EpisodeCard: View {
    let episode: MediaItem
    let baseURL: String
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Episode Thumbnail
                ZStack {
                    if let imageURL = episode.primaryImageURL(baseURL: baseURL, maxWidth: 400, quality: 90) {
                        AsyncImageView(url: imageURL, contentMode: .fill)
                            .frame(width: 400, height: 225)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 400, height: 225)
                    }

                    // Play overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 10)
                }
                .cornerRadius(8)

                // Episode Info
                VStack(alignment: .leading, spacing: 4) {
                    if let episodeNum = episode.indexNumber {
                        Text("Episode \(episodeNum)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(episode.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let overview = episode.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(width: 400, alignment: .leading)
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? .white.opacity(0.3) : .clear,
                radius: isFocused ? 15 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let mockItem = MediaItem(
        id: "1",
        name: "The Matrix Reloaded",
        type: "Movie",
        overview: "Six months after the events depicted in The Matrix, Neo has proved to be a good omen for the free humans, as more and more humans are being freed from the matrix and brought to Zion, the one and only stronghold of the Resistance.",
        productionYear: 2003,
        communityRating: 7.2,
        officialRating: "R",
        runTimeTicks: 8_280_000_000,
        imageTags: ImageTags(primary: "tag1", backdrop: "tag2", thumb: nil, logo: nil, banner: nil),
        imageBlurHashes: nil,
        userData: nil,
        seriesName: nil,
        seriesId: nil,
        seasonId: nil,
        indexNumber: nil,
        parentIndexNumber: nil,
        premiereDate: nil,
        genres: ["Action", "Science Fiction", "Thriller"],
        studios: [
            StudioInfo(name: "Warner Bros.", id: "1"),
            StudioInfo(name: "Village Roadshow Pictures", id: "2")
        ],
        people: nil,
        taglines: nil,
        mediaSources: nil,
        criticRating: nil,
        providerIds: nil,
        externalUrls: nil,
        remoteTrailers: nil,
        chapters: nil
    )

    let authService = AuthenticationService()
    let apiClient = JellyfinAPIClient()
    let viewModel = ItemDetailViewModel(item: mockItem, apiClient: apiClient, authService: authService)

    ItemDetailView(viewModel: viewModel)
}
