//
//  AsyncImageView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Async image view with caching, loading, and error states
struct AsyncImageView: View {
    let url: String?
    let placeholder: Image?
    let contentMode: ContentMode

    @StateObject private var loader = ImageLoader()
    @State private var showPlaceholder = true

    init(
        url: String?,
        placeholder: Image? = Image(systemName: "photo"),
        contentMode: ContentMode = .fill
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if loader.isLoading {
                ZStack {
                    Color.gray.opacity(0.2)

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white.opacity(0.7))
                }
            } else if loader.error != nil {
                ZStack {
                    Color.gray.opacity(0.2)

                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.gray)

                        Text("Failed to load")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else if let placeholder = placeholder {
                ZStack {
                    Color.gray.opacity(0.2)

                    placeholder
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                }
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onChange(of: url) { oldValue, newValue in
            loader.load(from: newValue)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

// MARK: - Poster-specific variant

struct PosterImageView: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImageView(url: url, contentMode: .fill)
            .frame(width: width, height: height)
            .clipped()
            .cornerRadius(Constants.UI.cardCornerRadius)
    }
}

// MARK: - Backdrop-specific variant

struct BackdropImageView: View {
    let url: String?
    let height: CGFloat

    var body: some View {
        AsyncImageView(url: url, contentMode: .fill)
            .frame(height: height)
            .clipped()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Poster example
        PosterImageView(
            url: nil,
            width: Constants.UI.posterWidth,
            height: Constants.UI.posterHeight
        )

        // Backdrop example
        BackdropImageView(
            url: nil,
            height: 300
        )

        // Custom example
        AsyncImageView(
            url: nil,
            placeholder: Image(systemName: "film"),
            contentMode: .fit
        )
        .frame(width: 200, height: 200)
        .background(Color.black)
    }
    .padding()
    .background(Color.black)
}
