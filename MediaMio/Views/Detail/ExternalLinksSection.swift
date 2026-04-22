//
//  ExternalLinksSection.swift
//  MediaMio
//
//  Renders `MediaItem.externalUrls` as a horizontal row of focusable pills
//  (IMDb, TMDB, Rotten Tomatoes, TVDB, etc.). On tvOS these are display-only
//  by default — there is no system browser to deep-link into; focusing the
//  pill is the interaction. The URL is copied into state so a future
//  companion-app handoff could read it.
//

import SwiftUI

struct ExternalLinksSection: View {
    let links: [ExternalURL]
    let communityRating: Double?
    let criticRating: Double?

    var body: some View {
        if links.isEmpty && communityRating == nil && criticRating == nil {
            EmptyView()
        } else {
            DetailSectionView(title: "Ratings & Links") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        if let rating = communityRating {
                            RatingPill(label: "Community", value: String(format: "%.1f", rating), icon: "star.fill")
                        }
                        if let rating = criticRating {
                            RatingPill(label: "Critics", value: "\(Int(rating))%", icon: "checkmark.seal.fill")
                        }
                        ForEach(links) { link in
                            ExternalLinkPill(link: link)
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }
        }
    }
}

// MARK: - Rating Pill

private struct RatingPill: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - External Link Pill

private struct ExternalLinkPill: View {
    let link: ExternalURL

    @FocusState private var hasFocus: Bool

    var body: some View {
        Button(action: {
            // tvOS has no system URL opener; surface the URL in the log for
            // companion-device handoff. When we add QR/handoff UX, that path
            // will replace this.
            print("🔗 External link focused: \(link.name) → \(link.url)")
        }) {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: link.name))
                    .font(.title3)
                Text(link.name)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(hasFocus ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(hasFocus ? 1.05 : 1.0)
            .shadow(color: hasFocus ? .white.opacity(0.3) : .clear, radius: hasFocus ? 12 : 0)
            .animation(.easeInOut(duration: 0.2), value: hasFocus)
        }
        .buttonStyle(.plain)
        .focused($hasFocus)
    }

    private func iconName(for provider: String) -> String {
        switch provider.lowercased() {
        case let p where p.contains("imdb"): return "film"
        case let p where p.contains("tmdb"): return "movieclapper"
        case let p where p.contains("rotten"): return "leaf"
        case let p where p.contains("tvdb"): return "tv"
        case let p where p.contains("trakt"): return "checkmark.circle"
        case let p where p.contains("youtube"): return "play.rectangle"
        default: return "link"
        }
    }
}
