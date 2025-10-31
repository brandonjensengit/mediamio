//
//  PosterCard.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Poster card component for displaying media items with tvOS focus effects
struct PosterCard: View {
    let item: MediaItem
    let baseURL: String
    let onSelect: () -> Void

    @Environment(\.isFocused) private var isFocused
    @State private var imageURL: String?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Poster Image
                ZStack(alignment: .bottomLeading) {
                    PosterImageView(
                        url: imageURL,
                        width: Constants.UI.posterWidth,
                        height: Constants.UI.posterHeight
                    )

                    // Progress indicator for resume items
                    if let progress = playbackProgress {
                        ProgressBar(progress: progress)
                            .frame(height: 6)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }
                }
                .frame(width: Constants.UI.posterWidth, height: Constants.UI.posterHeight)

                // Title
                Text(item.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(width: Constants.UI.posterWidth, alignment: .leading)

                // Metadata
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
            .scaleEffect(isFocused ? Constants.UI.focusScale : Constants.UI.normalScale)
            .shadow(
                color: isFocused ? .white.opacity(0.3) : .clear,
                radius: isFocused ? Constants.UI.focusShadowRadius : 0
            )
            .animation(.easeInOut(duration: Constants.UI.animationDuration), value: isFocused)
        }
        .buttonStyle(.plain)
        .onAppear {
            // Generate image URL
            imageURL = item.primaryImageURL(
                baseURL: baseURL,
                maxWidth: Constants.UI.posterImageMaxWidth,
                quality: Constants.UI.imageQuality
            )
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
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let progress: Double  // 0-100

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.3))

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
        taglines: nil
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
