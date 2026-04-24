//
//  TrailersSection.swift
//  MediaMio
//
//  Renders `MediaItem.remoteTrailers` as a horizontal row of tiles. On tvOS
//  the trailers are hosted off-platform (YouTube, mostly), so tiles show a
//  title + play icon as a promise; actual playback / companion-device handoff
//  is a follow-up.
//

import SwiftUI

struct TrailersSection: View {
    let trailers: [RemoteTrailer]

    var body: some View {
        if trailers.isEmpty {
            EmptyView()
        } else {
            DetailSectionView(title: "Trailers") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 30) {
                        ForEach(trailers) { trailer in
                            TrailerTile(trailer: trailer)
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }
        }
    }
}

// MARK: - Trailer Tile

private struct TrailerTile: View {
    let trailer: RemoteTrailer

    @FocusState private var hasFocus: Bool

    var body: some View {
        // `.focusable()` + `.onTapGesture` — NOT `Button(.plain)` — so tvOS
        // doesn't draw its focused-state background fill behind the tile.
        // `.focusEffectDisabled()` cannot reach that fill (it lives inside
        // the button style, not the focus-effect API). See `PosterCard`.
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.7), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.4), radius: 8)
            }
            .frame(width: 360, height: 200)
            .cornerRadius(10)

            Text(trailer.name ?? "Trailer")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: 360, alignment: .leading)
        }
        .contentFocus(isFocused: hasFocus)
        .focusable()
        .focused($hasFocus)
        .onTapGesture {
            print("🎬 Trailer focused: \(trailer.name ?? "Trailer") → \(trailer.url)")
        }
    }
}
