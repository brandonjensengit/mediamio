//
//  HeroBanner.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Large hero banner for featured content
struct HeroBanner: View {
    let item: MediaItem
    let baseURL: String
    let onPlay: () -> Void
    let onInfo: () -> Void

    @State private var backdropURL: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop Image
            if let url = backdropURL {
                AsyncImageView(url: url, contentMode: .fill)
                    .frame(height: Constants.UI.heroBannerHeight)
                    .clipped()
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: Constants.UI.heroBannerHeight)
            }

            // Gradient Overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.8),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Constants.UI.heroBannerHeight)

            // Content Overlay
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                // Title
                Text(item.name)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 10)

                // Metadata
                HStack(spacing: 16) {
                    if let year = item.yearText {
                        MetadataBadge(text: year, icon: nil)
                    }

                    if let rating = item.ratingText {
                        MetadataBadge(text: rating, icon: "star.fill")
                    }

                    if let runtime = item.runtimeFormatted {
                        MetadataBadge(text: runtime, icon: "clock")
                    }

                    if let officialRating = item.officialRating {
                        MetadataBadge(text: officialRating, icon: nil, style: .outlined)
                    }
                }

                // Overview
                if let overview = item.overview {
                    Text(overview)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.3), radius: 5)
                        .frame(maxWidth: 900, alignment: .leading)
                }

                // Action Buttons
                HStack(spacing: 20) {
                    // Play/Resume Button
                    HeroBannerButton(
                        title: hasProgress ? "Resume" : "Play",
                        icon: "play.fill",
                        style: .primary
                    ) {
                        onPlay()
                    }

                    // More Info Button
                    HeroBannerButton(
                        title: "More Info",
                        icon: "info.circle",
                        style: .secondary
                    ) {
                        onInfo()
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
        .frame(height: Constants.UI.heroBannerHeight)
        .onAppear {
            // Generate backdrop URL
            backdropURL = item.backdropImageURL(
                baseURL: baseURL,
                maxWidth: Constants.UI.backdropImageMaxWidth,
                quality: Constants.UI.imageQuality
            ) ?? item.primaryImageURL(
                baseURL: baseURL,
                maxWidth: Constants.UI.backdropImageMaxWidth,
                quality: Constants.UI.imageQuality
            )
        }
    }

    private var hasProgress: Bool {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            return false
        }

        let progress = Double(position) / Double(total) * 100.0
        return progress > 1.0 && progress < 95.0
    }
}

// MARK: - Hero Banner Button

struct HeroBannerButton: View {
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

// MARK: - Metadata Badge

struct MetadataBadge: View {
    let text: String
    let icon: String?
    let style: BadgeStyle

    init(text: String, icon: String?, style: BadgeStyle = .filled) {
        self.text = text
        self.icon = icon
        self.style = style
    }

    enum BadgeStyle {
        case filled
        case outlined
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }

            Text(text)
                .font(.headline)
        }
        .padding(.horizontal, style == .outlined ? 12 : 0)
        .padding(.vertical, style == .outlined ? 6 : 0)
        .foregroundColor(.white)
        .background(
            style == .outlined ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.5), lineWidth: 2) :
                nil
        )
    }
}

// MARK: - Preview

#Preview {
    let mockItem = MediaItem(
        id: "1",
        name: "The Matrix Reloaded",
        type: "Movie",
        overview: "Six months after the events depicted in The Matrix, Neo has proved to be a good omen for the free humans, as more and more humans are being freed from the matrix and brought to Zion.",
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
        genres: nil,
        studios: nil,
        people: nil,
        taglines: nil
    )

    HeroBanner(
        item: mockItem,
        baseURL: "https://demo.jellyfin.org/stable"
    ) {
        print("Play tapped")
    } onInfo: {
        print("Info tapped")
    }
    .background(Color.black)
}
