//
//  ContentRow.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Horizontal scrolling row of media content with Netflix-level focus memory.
/// Titles are intentionally non-focusable — row customization (move / hide)
/// lives in Settings → Home Layout, not as an inline affordance.
struct ContentRow: View {
    let section: ContentSection
    let baseURL: String
    /// Stable identity for this row used by the focus memos. Derived from
    /// `section.type.stableKey` at the call site.
    let rowKey: String
    let navigationManager: NavigationManager?
    let focusManager: FocusManager?
    let onItemSelect: (MediaItem) -> Void
    let onSeeAll: (() -> Void)?
    /// Routed to long-press context-menu actions on the cards in this row.
    /// Nil = no menu (Library / Search / Detail-similar rows today).
    let onContextAction: ((MediaItem, PosterContextAction) -> Void)?

    @FocusState private var focusedItemId: String?

    init(
        section: ContentSection,
        baseURL: String,
        rowKey: String? = nil,
        navigationManager: NavigationManager? = nil,
        focusManager: FocusManager? = nil,
        onItemSelect: @escaping (MediaItem) -> Void,
        onSeeAll: (() -> Void)? = nil,
        onContextAction: ((MediaItem, PosterContextAction) -> Void)? = nil
    ) {
        self.section = section
        self.baseURL = baseURL
        self.rowKey = rowKey ?? section.type.stableKey
        self.navigationManager = navigationManager
        self.focusManager = focusManager
        self.onItemSelect = onItemSelect
        self.onSeeAll = onSeeAll
        self.onContextAction = onContextAction
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

                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        cardView(for: item)
                            .focused($focusedItemId, equals: item.id)
                            .onChange(of: focusedItemId) { newValue in
                                if newValue == item.id {
                                    // This item is now focused, save to both managers
                                    navigationManager?.rememberFocus(rowKey: rowKey, itemIndex: index)
                                    focusManager?.focusedOnRow(rowKey, itemIndex: index)
                                }
                            }
                    }

                    // Trailing padding
                    Color.clear.frame(width: Constants.UI.defaultPadding - Constants.UI.cardSpacing)
                }
                .padding(.vertical, 40)  // Extra vertical padding to prevent clipping when cards scale
            }
            .frame(height: rowFrameHeight)
        }
    }

    // MARK: - Variant selection

    /// Resume rows use the 16:9 EpisodeThumbCard (streaming-app idiom).
    /// Live TV / DVR libraries also render 16:9 because their items are
    /// recordings or channel programs — Jellyfin only ships 16:9 thumb art
    /// for them, so 2:3 PosterCard shows broken-looking placeholders.
    /// Discovery rows for movies / tvshows / collections keep the 2:3
    /// PosterCard where keyart does the selling.
    private var useThumbVariant: Bool {
        switch section.type {
        case .continueWatching:
            return true
        case .library(_, _, let collectionType):
            return collectionType == "livetv"
        case .recentlyAdded, .recommended, .favorites:
            return false
        }
    }

    @ViewBuilder
    private func cardView(for item: MediaItem) -> some View {
        if useThumbVariant {
            EpisodeThumbCard(
                item: item,
                baseURL: baseURL,
                onSelect: { onItemSelect(item) },
                onContextAction: onContextAction.map { dispatch in
                    { action in dispatch(item, action) }
                }
            )
        } else {
            PosterCard(
                item: item,
                baseURL: baseURL,
                onSelect: { onItemSelect(item) },
                onContextAction: onContextAction.map { dispatch in
                    { action in dispatch(item, action) }
                }
            )
        }
    }

    /// Row frame accounts for card content plus scale-lift breathing room.
    private var rowFrameHeight: CGFloat {
        if useThumbVariant {
            // 225 image + 8 + ~28 primary + ~22 secondary + ~20 tertiary ≈ 303,
            // with 80pt of padding + scale room.
            return Constants.UI.thumbHeight + 180
        }
        return Constants.UI.posterHeight + 180
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
                .padding(.vertical, 40)
            }
            .frame(height: Constants.UI.posterHeight + 180)
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
