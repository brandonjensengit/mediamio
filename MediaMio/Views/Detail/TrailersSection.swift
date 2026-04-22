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
        Button(action: {
            print("🎬 Trailer focused: \(trailer.name ?? "Trailer") → \(trailer.url)")
        }) {
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
            .scaleEffect(hasFocus ? 1.05 : 1.0)
            .shadow(color: hasFocus ? .white.opacity(0.3) : .clear, radius: hasFocus ? 15 : 0)
            .animation(.easeInOut(duration: 0.2), value: hasFocus)
        }
        .buttonStyle(.plain)
        .focused($hasFocus)
    }
}
