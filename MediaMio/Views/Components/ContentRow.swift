//
//  ContentRow.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Horizontal scrolling row of media content
struct ContentRow: View {
    let section: ContentSection
    let baseURL: String
    let onItemSelect: (MediaItem) -> Void
    let onSeeAll: (() -> Void)?

    init(
        section: ContentSection,
        baseURL: String,
        onItemSelect: @escaping (MediaItem) -> Void,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.section = section
        self.baseURL = baseURL
        self.onItemSelect = onItemSelect
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            HStack {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                if let seeAll = onSeeAll {
                    Button(action: seeAll) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.headline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Constants.UI.defaultPadding)

            // Horizontal Scrolling Content
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Constants.UI.cardSpacing) {
                    // Leading padding
                    Color.clear.frame(width: Constants.UI.defaultPadding - Constants.UI.cardSpacing)

                    ForEach(section.items) { item in
                        PosterCard(
                            item: item,
                            baseURL: baseURL
                        ) {
                            onItemSelect(item)
                        }
                    }

                    // Trailing padding
                    Color.clear.frame(width: Constants.UI.defaultPadding - Constants.UI.cardSpacing)
                }
            }
            .frame(height: Constants.UI.posterHeight + 100)  // Poster + text + spacing
        }
    }
}

// MARK: - Empty State Variant

struct EmptyContentRow: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, Constants.UI.defaultPadding)

            VStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.5))

                Text(message)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        }
    }
}

// MARK: - Loading State Variant

struct LoadingContentRow: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, Constants.UI.defaultPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Constants.UI.cardSpacing) {
                    Color.clear.frame(width: Constants.UI.defaultPadding - Constants.UI.cardSpacing)

                    ForEach(0..<6, id: \.self) { _ in
                        LoadingPosterCard()
                    }

                    Color.clear.frame(width: Constants.UI.defaultPadding - Constants.UI.cardSpacing)
                }
            }
            .frame(height: Constants.UI.posterHeight + 100)
        }
    }
}

struct LoadingPosterCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: Constants.UI.posterWidth, height: Constants.UI.posterHeight)
                .cornerRadius(Constants.UI.cardCornerRadius)
                .shimmer(isAnimating: isAnimating)

            // Title placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: Constants.UI.posterWidth * 0.8, height: 20)
                .cornerRadius(4)
                .shimmer(isAnimating: isAnimating)

            // Metadata placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: Constants.UI.posterWidth * 0.5, height: 14)
                .cornerRadius(4)
                .shimmer(isAnimating: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Shimmer Effect

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        self.overlay(
            GeometryReader { geometry in
                if isAnimating {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                }
            }
        )
        .clipped()
    }
}

// MARK: - Preview

#Preview {
    let mockItems = (0..<10).map { index in
        MediaItem(
            id: "\(index)",
            name: "Movie \(index + 1)",
            type: "Movie",
            overview: nil,
            productionYear: 2020 + index,
            communityRating: 7.5 + Double(index) * 0.1,
            officialRating: nil,
            runTimeTicks: 7_200_000_000,
            imageTags: ImageTags(primary: "tag", backdrop: nil, thumb: nil, logo: nil, banner: nil),
            imageBlurHashes: nil,
            userData: nil,
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
    }

    let section = ContentSection(
        title: "Recently Added",
        items: mockItems,
        type: .recentlyAdded
    )

    VStack(spacing: 40) {
        ContentRow(
            section: section,
            baseURL: "https://demo.jellyfin.org/stable"
        ) { item in
            print("Selected: \(item.name)")
        } onSeeAll: {
            print("See All tapped")
        }

        LoadingContentRow(title: "Loading...")

        EmptyContentRow(
            title: "Recently Added",
            message: "No recently added items"
        )
    }
    .background(Color.black)
}
