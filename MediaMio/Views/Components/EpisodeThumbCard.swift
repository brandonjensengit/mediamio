//
//  EpisodeThumbCard.swift
//  MediaMio
//
//  Created by Claude Code
//
//  Phase 2 / Item B — 16:9 landscape tile for the Continue Watching shelf.
//  PosterCard stays for discovery shelves (movies, libraries) where the
//  2:3 keyart is the right language; this card is the streaming-app
//  idiom for "resume where you left off". Jellyfin gives us the 16:9
//  still via `MediaItem.landscapeImageURL`; the 4pt progress bar across
//  the bottom matches Apple TV / Netflix / Disney+ conventions.
//

import SwiftUI

/// 16:9 landscape tile used on the Continue Watching shelf. Renders:
/// - 400×225pt still with a 4pt progress bar at the bottom edge
/// - primary label (series for episodes, title for movies)
/// - secondary label ("S2 E4 · Episode Name" for episodes)
/// - tertiary "23m left" in accent color
struct EpisodeThumbCard: View {
    let item: MediaItem
    let baseURL: String
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool
    @State private var imageURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                // 16:9 still
                ZStack(alignment: .bottom) {
                    AsyncImageView(
                        url: imageURL,
                        contentMode: .fill,
                        targetPixelSize: ImageSizing.pixelSize(
                            points: CGSize(
                                width: Constants.UI.thumbWidth,
                                height: Constants.UI.thumbHeight
                            )
                        )
                    )
                    .frame(
                        width: Constants.UI.thumbWidth,
                        height: Constants.UI.thumbHeight
                    )
                    .clipped()

                    // Scrim above the progress bar so it reads over bright stills.
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 48)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    // Progress bar — 4pt, flush to the bottom edge.
                    if let progress = playbackProgress {
                        ProgressBar(progress: progress)
                            .frame(height: 4)
                    }
                }
                .frame(
                    width: Constants.UI.thumbWidth,
                    height: Constants.UI.thumbHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))

                // Primary label
                Text(primaryLabel)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: Constants.UI.thumbWidth, alignment: .leading)

                // Secondary label (episode locator / subtitle)
                if let secondary = secondaryLabel {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                        .frame(width: Constants.UI.thumbWidth, alignment: .leading)
                }

                // Tertiary "23m left" line
                if let remaining = item.remainingText {
                    Text(remaining)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Colors.accent)
                        .frame(width: Constants.UI.thumbWidth, alignment: .leading)
                }
        }
        .contentFocus(isFocused: isFocused)
        .zIndex(isFocused ? 999 : 0)
        .focusable()
        .focused($isFocused)
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            imageURL = item.landscapeImageURL(
                baseURL: baseURL,
                maxWidth: Constants.UI.thumbImageMaxWidth,
                quality: Constants.UI.imageQuality
            )
        }
    }

    // MARK: - Labels

    private var primaryLabel: String {
        if item.isEpisode, let series = item.seriesName, !series.isEmpty {
            return series
        }
        return item.name
    }

    private var secondaryLabel: String? {
        if item.isEpisode {
            if let locator = item.episodeText {
                return "\(locator) · \(item.name)"
            }
            return item.name
        }
        return nil
    }

    // MARK: - Progress

    private var playbackProgress: Double? {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks,
              total > 0 else {
            return nil
        }
        let progress = Double(position) / Double(total) * 100.0
        // Resume items are almost always between 1% and 95%; outside that
        // range the shelf shouldn't even have sent us the item, but guard
        // anyway.
        if progress > 1.0 && progress < 95.0 {
            return progress
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    let episode = MediaItem(
        id: "ep1",
        name: "The One Where Ross Gets Divorced",
        type: "Episode",
        overview: nil,
        productionYear: 1998,
        communityRating: 8.2,
        officialRating: nil,
        runTimeTicks: 13_800_000_000,  // 23 min
        imageTags: ImageTags(primary: "tag", backdrop: nil, thumb: nil, logo: nil, banner: nil),
        imageBlurHashes: nil,
        userData: UserData(
            playbackPositionTicks: 4_140_000_000,  // 30%
            playCount: 0,
            isFavorite: false,
            played: false,
            key: nil
        ),
        seriesName: "Friends",
        seriesId: "s1",
        seasonId: "s1s5",
        indexNumber: 1,
        parentIndexNumber: 5,
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

    EpisodeThumbCard(
        item: episode,
        baseURL: "https://demo.jellyfin.org/stable"
    ) {
        print("Selected: \(episode.name)")
    }
    .padding(40)
    .background(Constants.Colors.background)
}
