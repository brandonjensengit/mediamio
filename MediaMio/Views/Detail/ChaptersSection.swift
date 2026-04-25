//
//  ChaptersSection.swift
//  MediaMio
//
//  Renders `MediaItem.chapters` as a horizontal thumbnail strip on Detail.
//  Tapping a chapter starts playback at that offset via
//  NavigationManager.playItem(_:startPositionTicks:).
//
//  Jellyfin serves chapter thumbnails at /Items/{id}/Images/Chapter/{index},
//  indexed by position in the chapters array (not by ImageTag). The `imageTag`
//  field is a cache-buster presence flag: when nil, the chapter has no image
//  and we fall back to a gradient placeholder with the chapter name.
//

import SwiftUI

struct ChaptersSection: View {
    let item: MediaItem
    let baseURL: String
    let onChapterTap: (Chapter) -> Void

    var body: some View {
        guard let chapters = item.chapters, !chapters.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            DetailSectionView(title: "Chapters") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 24) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            ChapterTile(
                                chapter: chapter,
                                index: index,
                                item: item,
                                baseURL: baseURL
                            ) {
                                onChapterTap(chapter)
                            }
                        }
                    }
                    .padding(.horizontal, Constants.UI.defaultPadding)
                }
            }
        )
    }
}

private struct ChapterTile: View {
    let chapter: Chapter
    let index: Int
    let item: MediaItem
    let baseURL: String
    let action: () -> Void

    @FocusState private var hasFocus: Bool

    private var hasImage: Bool {
        chapter.imageTag?.isEmpty == false
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                    .frame(width: 320, height: 180)
                    .cornerRadius(8)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(chapter.formattedStart)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 320, alignment: .leading)
            }
            .contentFocus(isFocused: hasFocus)
        }
        .buttonStyle(.cardChrome)
        .focused($hasFocus)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if hasImage {
            let url = item.chapterImageURL(
                baseURL: baseURL,
                chapterIndex: index,
                maxWidth: 400
            )
            AsyncImageView(url: url, contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(chapter.formattedStart)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
