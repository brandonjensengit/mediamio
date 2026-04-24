//
//  ExternalLinksSection.swift
//  MediaMio
//
//  Renders `MediaItem.externalUrls` as a horizontal row of focusable pills
//  (IMDb, TMDB, Rotten Tomatoes, TVDB, etc.). tvOS has no system browser,
//  so tapping a pill presents a QR-code handoff sheet — the viewer scans
//  with their phone to open the link there.
//

import SwiftUI

struct ExternalLinksSection: View {
    let links: [ExternalURL]
    let communityRating: Double?
    let criticRating: Double?

    @State private var presentedLink: ExternalURL?

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
                            ExternalLinkPill(link: link) {
                                presentedLink = link
                            }
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }
            .sheet(item: $presentedLink) { link in
                QRHandoffView(
                    title: link.name,
                    subtitle: "Open this link on your phone to view on \(link.name)",
                    url: link.url
                )
            }
        }
    }
}

// MARK: - Rating Pill

/// Non-interactive sibling of the link pill — same surface/padding/shape
/// so the row reads as one design even though only the link pills focus.
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
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            Constants.Colors.surface2,
            in: RoundedRectangle(cornerRadius: Constants.UI.cornerRadius, style: .continuous)
        )
    }
}

// MARK: - External Link Pill

private struct ExternalLinkPill: View {
    let link: ExternalURL
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: link.name))
                    .font(.title3)
                Text(link.name)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        // Routes through the shared Detail focus-ring style: tight amber
        // stroke matching the button shape, no system white halo. Slimmer
        // padding + smaller min-width than the Play/Favorite hero CTAs
        // since the link row is dense and these aren't primary actions.
        .buttonStyle(DetailActionButtonStyle(
            backgroundColor: Constants.Colors.surface2,
            foregroundColor: .white,
            minWidth: 0,
            horizontalPadding: 28,
            verticalPadding: 14
        ))
        .focusEffectDisabled()
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
