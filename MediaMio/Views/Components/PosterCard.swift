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

    @FocusState private var isFocused: Bool
    @State private var imageURL: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                // Poster Image
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
        .scaleEffect(isFocused ? 1.15 : 1.0)  // Increased from 1.1 to 1.15 for more pop
        .shadow(
            color: isFocused ? .black.opacity(0.8) : .clear,  // Darker shadow
            radius: isFocused ? 30 : 0,  // Larger blur radius
            x: 0,
            y: isFocused ? 15 : 0  // More vertical offset for depth
        )
        .zIndex(isFocused ? 999 : 0)  // Much higher z-index to ensure it's on top
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .allowsHitTesting(true)
        .focusable()
        .focused($isFocused)
        .onTapGesture {
            onSelect()
        }
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
        taglines: nil,
        mediaSources: nil
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
