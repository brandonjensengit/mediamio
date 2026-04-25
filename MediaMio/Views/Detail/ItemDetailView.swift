//
//  ItemDetailView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// First-paint skeleton for Detail — fills the gap between "header rendered
/// from the sparse MediaItem we were pushed with" and "full detail payload
/// arrived." Shimmer tiles mirror the final Overview → Metadata → Cast →
/// Similar layout so there's no layout shift when the real content lands.
private struct DetailSkeletonBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            // Overview — three text-line shimmers
            VStack(alignment: .leading, spacing: 16) {
                ShimmerTile(cornerRadius: 6).frame(width: 220, height: 24)
                VStack(alignment: .leading, spacing: 12) {
                    ShimmerTile(cornerRadius: 4).frame(height: 20)
                    ShimmerTile(cornerRadius: 4).frame(height: 20)
                    ShimmerTile(cornerRadius: 4).frame(maxWidth: 900, alignment: .leading).frame(height: 20)
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)

            // Metadata — four label/value pairs
            VStack(alignment: .leading, spacing: 16) {
                ShimmerTile(cornerRadius: 6).frame(width: 180, height: 24)
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 40) {
                        ShimmerTile(cornerRadius: 4).frame(width: 160, height: 18)
                        ShimmerTile(cornerRadius: 4).frame(maxWidth: 600, alignment: .leading).frame(height: 18)
                    }
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)

            // Cast — six circular shimmers
            VStack(alignment: .leading, spacing: 16) {
                ShimmerTile(cornerRadius: 6).frame(width: 160, height: 24)
                HStack(spacing: 24) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 12) {
                            ShimmerTile(cornerRadius: 80).frame(width: 160, height: 160)
                            ShimmerTile(cornerRadius: 4).frame(width: 140, height: 16)
                        }
                    }
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)

            // More Like This — six poster-shaped shimmers
            VStack(alignment: .leading, spacing: 16) {
                ShimmerTile(cornerRadius: 6).frame(width: 200, height: 24)
                HStack(spacing: Constants.UI.cardSpacing) {
                    ForEach(0..<6, id: \.self) { _ in
                        ShimmerTile()
                            .frame(width: Constants.UI.posterWidth, height: Constants.UI.posterHeight)
                    }
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
    }
}

struct ItemDetailView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    @Environment(\.dismiss) private var dismiss

    /// Namespace shared between the lower-left CTA row and the scroll scope
    /// so `.prefersDefaultFocus(true, in:)` on Play wins the initial-focus
    /// contest on every fresh presentation. Imperative `focusedButton = .play`
    /// hacks have been retired.
    @Namespace private var detailFocusNamespace

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Backdrop Header
                    DetailHeaderView(
                        viewModel: viewModel,
                        focusNamespace: detailFocusNamespace
                    )

                    // Content — skeleton while the details payload is in
                    // flight and we only have the sparse list-endpoint item.
                    if viewModel.isLoading && viewModel.detailedItem == nil {
                        DetailSkeletonBody()
                            .padding(.top, 40)
                            .padding(.bottom, 80)
                    } else {
                        detailContent
                            .padding(.top, 40)
                            .padding(.bottom, 80)
                    }
                }
            }
            .id(viewModel.item.id)  // Force ScrollView to recreate at position 0
            .focusScope(detailFocusNamespace)
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

    /// The real populated-detail content stack. Kept as a computed property
    /// so the skeleton branch above stays symmetrical and the outer body
    /// reads as a two-branch load gate.
    private var detailContent: some View {
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

            // Trailers — hidden for now. Off-platform (YouTube) so there's
            // no in-app playback yet, and the tiles were adding focus
            // noise. Re-enable by restoring the block below.
            //
            // if let trailers = displayItem.remoteTrailers, !trailers.isEmpty {
            //     TrailersSection(trailers: trailers)
            // }

            // Cast & Crew — hidden for now. Focus routing from the
            // description to the row still needs work, and the section
            // isn't essential for the cinematic-commit flow. Re-enable
            // by restoring the block below.
            //
            // if let people = displayItem.people, !people.isEmpty {
            //     CastCrewSection(people: people, baseURL: viewModel.baseURL)
            // }

            // Chapters demoted below Cast & Crew on Movies (was
            // directly under External Links, stealing focus from
            // Play and crowding the cinematic commit). Series
            // detail stays chapter-free.
            if displayItem.type != "Series" {
                ChaptersSection(
                    item: displayItem,
                    baseURL: viewModel.baseURL
                ) { chapter in
                    viewModel.playChapter(chapter)
                }
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
    }
}

// MARK: - Detail Header

/// Full-bleed cinematic header (Apple TV / Netflix idiom). Backdrop fills the
/// ~720pt stage; title treatment, metadata, and CTAs anchor lower-left inside
/// the safe area. No poster column — that composition was a library-browser
/// pattern (Sonarr / Radarr / Jellyfin Web) at odds with a playback client.
///
/// Empty-backdrop fallback renders the title treatment centered above a
/// `surface1` + gradient stage instead of the old `.blur(radius: 80)` poster
/// ambient, which was a per-frame GPU kill for negligible value.
struct DetailHeaderView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    let focusNamespace: Namespace.ID

    @State private var backdropURL: String?
    @State private var showPlayChoice: Bool = false

    private static let headerHeight: CGFloat = 720
    private static let horizontalPadding: CGFloat = 80
    private static let bottomPadding: CGFloat = 80

    var body: some View {
        let displayItem = viewModel.detailedItem ?? viewModel.item

        ZStack(alignment: .bottomLeading) {
            backdropLayer
            gradientLayer

            // When no backdrop exists the title treatment fills the empty
            // stage centered in the upper portion. The lower-left info stack
            // still carries the metadata + CTAs so the interaction model is
            // stable across both branches.
            if backdropURL == nil {
                TitleTreatment(
                    item: displayItem,
                    baseURL: viewModel.baseURL,
                    maxWidth: 700,
                    maxHeight: 240,
                    textFontSize: 72,
                    alignment: .center
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 80)
            }

            infoColumn(displayItem: displayItem)
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.bottom, Self.bottomPadding)
        }
        .frame(height: Self.headerHeight)
        .onAppear { updateBackdropURL() }
        .onChange(of: viewModel.detailedItem) { _ in
            updateBackdropURL()
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
            GeometryReader { geometry in
                AsyncImageView(
                    url: url,
                    contentMode: .fill,
                    targetPixelSize: ImageSizing.pixelSize(
                        points: CGSize(width: geometry.size.width, height: Self.headerHeight)
                    )
                )
                // `alignment: .top` anchors the fill so vertical overflow
                // is pushed DOWN and cropped at the bottom — the gradient
                // overlay already fades that region to black, so the crop
                // is invisible. Center-aligned fill (the default) cut ~180pt
                // off the top of 16:9 backdrops, eating the main subject.
                .frame(width: geometry.size.width, height: Self.headerHeight, alignment: .top)
                .clipped()
            }
            .frame(height: Self.headerHeight)
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

    private func infoColumn(displayItem: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // When a real backdrop is behind us, the title treatment lives
            // inline at the top of the info stack (lower-left anchor). The
            // no-backdrop branch above already rendered a centered version.
            // Constrained to ~400×120 (vs the 600×180 hero default) so it
            // reads as a brand-mark accent, not a second title — Series
            // backdrops often bake the title into the artwork already.
            if backdropURL != nil {
                TitleTreatment(
                    item: displayItem,
                    baseURL: viewModel.baseURL,
                    maxWidth: 400,
                    maxHeight: 120
                )
            }

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
                    .prefersDefaultFocus(true, in: focusNamespace)

                    DetailActionButton(
                        title: viewModel.isFavorite ? "Unfavorite" : "Favorite",
                        icon: viewModel.isFavorite ? "heart.fill" : "heart",
                        style: .secondary
                    ) {
                        viewModel.toggleFavorite()
                    }
                }
                .focusSection()
            }
        }
        .frame(maxWidth: 1100, alignment: .leading)
    }

    /// "2026 · PG-13 · 1h 38m · ★ 7.5" — same single-line treatment HeroBanner uses.
    /// Series omit the runtime slot: Jellyfin returns per-episode runtime
    /// (often 0 on the Series root), which renders as a misleading "0m".
    private func metadataLine(for item: MediaItem) -> String? {
        var parts: [String] = []
        if let year = item.yearText { parts.append(year) }
        if let officialRating = item.officialRating, !officialRating.isEmpty {
            parts.append(officialRating)
        }
        if item.type != "Series", let runtime = item.runtimeFormatted {
            parts.append(runtime)
        }
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

    private func updateBackdropURL() {
        let displayItem = viewModel.detailedItem ?? viewModel.item
        // `heroBackdropImageURL` cascades through Backdrop → Thumb →
        // parent-series Backdrop → parent-series Thumb → Episode `Primary`,
        // so Episodes and backdrop-less Movies get a real landscape image
        // instead of falling through to the logo-on-dark-stage branch.
        backdropURL = displayItem.heroBackdropImageURL(
            baseURL: viewModel.baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
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
            .contentFocus(isFocused: isFocused)
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
        chapters: nil,
        parentLogoItemId: nil,
        parentLogoImageTag: nil
    )

    let apiClient = JellyfinAPIClient()
    let authService = AuthenticationService(apiClient: apiClient)
    let viewModel = ItemDetailViewModel(item: mockItem, apiClient: apiClient, authService: authService)

    ItemDetailView(viewModel: viewModel)
}
