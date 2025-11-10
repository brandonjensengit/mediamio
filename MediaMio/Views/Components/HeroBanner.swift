//
//  HeroBanner.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Large hero banner for featured content with Netflix-style auto-rotation
struct HeroBanner: View {
    let item: MediaItem
    let baseURL: String
    let onPlay: () -> Void
    let onInfo: () -> Void

    @State private var backdropURL: String?

    var body: some View {
        HeroBannerContent(
            item: item,
            baseURL: baseURL,
            backdropURL: backdropURL,
            onPlay: onPlay,
            onInfo: onInfo
        )
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
}

/// Multi-item hero banner with auto-rotation (Netflix-style)
struct HeroBannerRotating: View {
    let items: [MediaItem]
    let baseURL: String
    let onPlay: (MediaItem) -> Void
    let onInfo: (MediaItem) -> Void

    @State private var currentIndex: Int = 0
    @State private var rotationTimer: Timer?
    @State private var isButtonFocused: Bool = false

    private let rotationInterval: TimeInterval = 8.0
    private let transitionDuration: TimeInterval = 0.8

    var body: some View {
        ZStack {
            if !items.isEmpty {
                // Multiple backdrops with crossfade
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HeroBannerContent(
                        item: item,
                        baseURL: baseURL,
                        backdropURL: generateBackdropURL(for: item),
                        onPlay: { onPlay(item) },
                        onInfo: { onInfo(item) },
                        onFocusChange: { focused in
                            isButtonFocused = focused
                        }
                    )
                    .opacity(index == currentIndex ? 1 : 0)
                    .animation(.easeInOut(duration: transitionDuration), value: currentIndex)
                }
            } else {
                // Empty state
                Color.black
                    .frame(height: Constants.UI.heroBannerHeight)
            }
        }
        .frame(height: Constants.UI.heroBannerHeight)
        .onAppear {
            startAutoRotation()
        }
        .onDisappear {
            stopAutoRotation()
        }
        .onChange(of: isButtonFocused) { focused in
            if focused {
                stopAutoRotation()
            } else {
                startAutoRotation()
            }
        }
    }

    private func generateBackdropURL(for item: MediaItem) -> String? {
        return item.backdropImageURL(
            baseURL: baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
            quality: Constants.UI.imageQuality
        ) ?? item.primaryImageURL(
            baseURL: baseURL,
            maxWidth: Constants.UI.backdropImageMaxWidth,
            quality: Constants.UI.imageQuality
        )
    }

    private func startAutoRotation() {
        guard items.count > 1 else { return }

        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % items.count
            }
        }
    }

    private func stopAutoRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }
}

/// Shared hero banner content view
private struct HeroBannerContent: View {
    let item: MediaItem
    let baseURL: String
    let backdropURL: String?
    let onPlay: () -> Void
    let onInfo: () -> Void
    var onFocusChange: ((Bool) -> Void)? = nil

    @State private var playButtonFocused: Bool = false
    @State private var infoButtonFocused: Bool = false

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
                        style: .primary,
                        onFocusChange: { focused in
                            playButtonFocused = focused
                            onFocusChange?(focused)
                        }
                    ) {
                        onPlay()
                    }

                    // More Info Button
                    HeroBannerButton(
                        title: "More Info",
                        icon: "info.circle",
                        style: .secondary,
                        onFocusChange: { focused in
                            infoButtonFocused = focused
                            onFocusChange?(focused)
                        }
                    ) {
                        onInfo()
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Constants.UI.defaultPadding)
        }
    }

    private var hasProgress: Bool {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            print("📊 HeroBanner: hasProgress=false for '\(item.name)': userData=\(item.userData != nil), position=\(item.userData?.playbackPositionTicks != nil), total=\(item.runTimeTicks != nil)")
            return false
        }

        let progress = Double(position) / Double(total) * 100.0
        let hasProgress = progress > 1.0 && progress < 95.0
        print("📊 HeroBanner: hasProgress=\(hasProgress) for '\(item.name)': position=\(position), total=\(total), progress=\(String(format: "%.1f", progress))%")
        return hasProgress
    }
}

// MARK: - Hero Banner Button

struct HeroBannerButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    var onFocusChange: ((Bool) -> Void)? = nil
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.clear, lineWidth: 0)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? .white.opacity(0.3) : .clear,
                radius: isFocused ? 15 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
        .onChange(of: isFocused) { focused in
            onFocusChange?(focused)
        }
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
        taglines: nil,
        mediaSources: nil
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
