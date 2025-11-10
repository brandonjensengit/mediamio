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
            Color.black.ignoresSafeArea()

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
        }
        .task {
            await viewModel.loadDetails()
        }
    }
}

// MARK: - Detail Header

struct DetailHeaderView: View {
    @ObservedObject var viewModel: ItemDetailViewModel
    @State private var backdropURL: String?
    @FocusState private var focusedButton: FocusableButton?

    enum FocusableButton {
        case play
        case favorite
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Backdrop Image
            if let url = backdropURL {
                GeometryReader { geometry in
                    AsyncImageView(url: url, contentMode: .fill)
                        .frame(width: geometry.size.width)
                        .offset(y: -100)  // Shift up slightly to show upper-middle portion
                }
                .frame(height: 700)
                .clipped()
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: 700)
            }

            // Gradient Overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.9),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 700)

            // Content
            VStack(alignment: .leading, spacing: 24) {
                let displayItem = viewModel.detailedItem ?? viewModel.item

                // Title
                Text(displayItem.name)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 10)

                // Metadata Badges
                HStack(spacing: 16) {
                    if let year = displayItem.yearText {
                        MetadataBadge(text: year, icon: nil)
                    }

                    if let rating = displayItem.ratingText {
                        MetadataBadge(text: rating, icon: "star.fill")
                    }

                    if let runtime = displayItem.runtimeFormatted {
                        MetadataBadge(text: runtime, icon: "clock")
                    }

                    if let officialRating = displayItem.officialRating {
                        MetadataBadge(text: officialRating, icon: nil, style: .outlined)
                    }
                }

                // Progress Bar
                if viewModel.hasProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(viewModel.progressPercentage))% watched")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))

                        ProgressBar(progress: viewModel.progressPercentage / 100.0)
                            .frame(height: 6)
                            .frame(maxWidth: 600)
                    }
                }

                // Action Buttons (hide Play for Series - episodes shown below)
                if displayItem.type != "Series" {
                    HStack(spacing: 24) {
                        // Play/Resume Button (default focus)
                        DetailActionButton(
                            title: viewModel.hasProgress ? "Resume" : "Play",
                            icon: "play.fill",
                            style: .primary
                        ) {
                            viewModel.playItem()
                        }
                        .focused($focusedButton, equals: .play)

                        // Favorite Button
                        DetailActionButton(
                            title: viewModel.isFavorite ? "Unfavorite" : "Favorite",
                            icon: viewModel.isFavorite ? "heart.fill" : "heart",
                            style: .secondary
                        ) {
                            viewModel.toggleFavorite()
                        }
                        .focused($focusedButton, equals: .favorite)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
        .frame(height: 700)
        .onAppear {
            updateBackdropURL()
            // Set default focus to Play button (Netflix-level UX)
            focusedButton = .play
        }
        .onChange(of: viewModel.detailedItem) { _ in
            updateBackdropURL()
        }
    }

    private func updateBackdropURL() {
        let displayItem = viewModel.detailedItem ?? viewModel.item

        let url = displayItem.backdropImageURL(
            baseURL: viewModel.baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
            quality: Constants.UI.imageQuality
        ) ?? displayItem.primaryImageURL(
            baseURL: viewModel.baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
            quality: Constants.UI.imageQuality
        )

        backdropURL = url
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

    @Environment(\.isFocused) private var isFocused

    enum ButtonStyle {
        case primary
        case secondary

        var backgroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return Color.white.opacity(0.2)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return .black
            case .secondary: return .white
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(8)
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
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(isSelected ? Color.white : Color.white.opacity(0.2))
                .cornerRadius(8)
                .scaleEffect(isFocused ? 1.05 : 1.0)
                .shadow(
                    color: isFocused ? .white.opacity(0.3) : .clear,
                    radius: isFocused ? 15 : 0
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
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
        mediaSources: nil
    )

    let authService = AuthenticationService()
    let apiClient = JellyfinAPIClient()
    let viewModel = ItemDetailViewModel(item: mockItem, apiClient: apiClient, authService: authService)

    ItemDetailView(viewModel: viewModel)
}
