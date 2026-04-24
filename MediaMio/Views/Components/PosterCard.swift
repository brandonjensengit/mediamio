//
//  PosterCard.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Poster card component for displaying media items with tvOS focus effects.
///
/// Phase 2 / Item F: wrapped in a `Button` with `.buttonStyle(.card)` so the
/// native tvOS focus lift + parallax + specular shine kicks in for free.
/// Replaces the previous `.focusable() + .onTapGesture` pattern, which
/// bypassed every one of those free affordances.
///
/// `onContextAction` is optional — when nil, the long-press menu is empty
/// and tvOS skips it. Home wires a handler; Library / Search / Detail pass
/// nil until their own Phase-F polish lands.
struct PosterCard: View {
    let item: MediaItem
    let baseURL: String
    let onSelect: () -> Void
    var onContextAction: ((PosterContextAction) -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var imageURL: String?

    @ViewBuilder
    var body: some View {
        // `.focusable()` + `.onTapGesture` (no Button wrapper) so tvOS
        // doesn't draw its plain-button focused-state background —
        // `.focusEffectDisabled()` can't reach that fill because it lives
        // inside the button style, not the focus-effect API.
        //
        // `.contextMenu` is attached conditionally: on tvOS 26 an empty
        // `.contextMenu { }` captures Select before `.onTapGesture` sees
        // it, breaking activation on every callsite that doesn't wire
        // `onContextAction` (Library / Search / Detail-similar — all nil
        // by design). Only attach when we have something to show.
        if onContextAction != nil {
            cardLayout.contextMenu { contextMenuContent }
        } else {
            cardLayout
        }
    }

    private var cardLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            posterImage

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(width: Constants.UI.posterWidth, alignment: .leading)

                metadataRow
            }
        }
        .focusable()
        .focused($isFocused)
        .contentFocus(isFocused: isFocused)
        .zIndex(isFocused ? 999 : 0)
        .onTapGesture { onSelect() }
        .onAppear {
            imageURL = item.primaryImageURL(
                baseURL: baseURL,
                maxWidth: Constants.UI.posterImageMaxWidth,
                quality: Constants.UI.imageQuality
            )
        }
    }

    // MARK: - Poster image

    private var posterImage: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImageView(
                url: imageURL,
                width: Constants.UI.posterWidth,
                height: Constants.UI.posterHeight
            )

            // Dark gradient at bottom for text readability
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Progress indicator for resume items
            if let progress = playbackProgress {
                ProgressBar(progress: progress)
                    .frame(height: 6)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: Constants.UI.posterWidth, height: Constants.UI.posterHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Metadata row

    private var metadataRow: some View {
        HStack(spacing: 6) {
            if let year = item.yearText {
                Text(year)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let rating = item.ratingText {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(rating)
                        .font(.caption)
                }
                .foregroundColor(.yellow)
            }

            if let runtime = item.runtimeFormatted {
                Text(runtime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let episode = item.episodeText {
                Text(episode)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: Constants.UI.posterWidth, alignment: .leading)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if let dispatch = onContextAction {
            if hasProgress {
                Button {
                    dispatch(.playFromBeginning)
                } label: {
                    Label("Play from Beginning", systemImage: "gobackward")
                }
            }

            Button {
                dispatch(.toggleWatched)
            } label: {
                Label(
                    isPlayed ? "Mark as Unwatched" : "Mark as Watched",
                    systemImage: isPlayed ? "eye.slash" : "eye"
                )
            }

            Button {
                dispatch(.toggleFavorite)
            } label: {
                Label(
                    isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: isFavorite ? "heart.slash" : "heart"
                )
            }

            if item.isEpisode, item.seriesId != nil {
                Button {
                    dispatch(.goToSeries)
                } label: {
                    Label("Go to Series", systemImage: "tv")
                }
            }

            if hasProgress {
                Button(role: .destructive) {
                    dispatch(.removeFromResume)
                } label: {
                    Label("Remove from Continue Watching", systemImage: "minus.circle")
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var playbackProgress: Double? {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks,
              total > 0 else {
            return nil
        }

        let progress = Double(position) / Double(total) * 100.0

        // Only show progress bar if between 1% and 95%
        if progress > 1.0 && progress < 95.0 {
            return progress
        }

        return nil
    }

    private var hasProgress: Bool {
        playbackProgress != nil
    }

    private var isPlayed: Bool {
        item.userData?.played ?? false
    }

    private var isFavorite: Bool {
        item.userData?.isFavorite ?? false
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double  // 0-100

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Constants.Colors.surface2.opacity(0.8))

                // Progress
                Rectangle()
                    .fill(Constants.Colors.primary)
                    .frame(width: geometry.size.width * CGFloat(progress / 100.0))
            }
            .cornerRadius(3)
        }
    }
}

// MARK: - Preview

#Preview {
    let mockItem = MediaItem(
        id: "1",
        name: "The Matrix",
        type: "Movie",
        overview: "A computer hacker learns from mysterious rebels about the true nature of his reality.",
        productionYear: 1999,
        communityRating: 8.7,
        officialRating: "R",
        runTimeTicks: 8_160_000_000,  // 136 minutes in ticks
        imageTags: ImageTags(primary: "tag1", backdrop: nil, thumb: nil, logo: nil, banner: nil),
        imageBlurHashes: nil,
        userData: UserData(
            playbackPositionTicks: 2_448_000_000,  // 30% watched
            playCount: 0,
            isFavorite: false,
            played: false,
            key: nil
        ),
        seriesName: nil,
        seriesId: nil,
        seasonId: nil,
        indexNumber: nil,
        parentIndexNumber: nil,
        premiereDate: nil,
        genres: nil,
        studios: nil,
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

    PosterCard(
        item: mockItem,
        baseURL: "https://demo.jellyfin.org/stable"
    ) {
        print("Selected: \(mockItem.name)")
    }
    .padding()
    .background(Color.black)
}
