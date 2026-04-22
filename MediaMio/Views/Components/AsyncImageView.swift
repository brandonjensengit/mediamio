//
//  AsyncImageView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Async image view with caching, loading, and error states.
/// When `targetPixelSize` is set, ImageLoader decodes via ImageIO at that resolution,
/// avoiding the multi-tens-of-MB-per-image cost of decoding 4K backdrops at full res.
struct AsyncImageView: View {
    let url: String?
    let placeholder: Image?
    let contentMode: ContentMode
    let targetPixelSize: CGSize?

    @StateObject private var loader = ImageLoader()
    @State private var showPlaceholder = true

    init(
        url: String?,
        placeholder: Image? = Image(systemName: "photo"),
        contentMode: ContentMode = .fill,
        targetPixelSize: CGSize? = nil
    ) {
        self.url = url
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.targetPixelSize = targetPixelSize
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
            loader.load(from: url, targetPixelSize: targetPixelSize)
        }
        .onChange(of: url) { oldValue, newValue in
            loader.load(from: newValue, targetPixelSize: targetPixelSize)
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
        AsyncImageView(
            url: url,
            contentMode: .fill,
            targetPixelSize: ImageSizing.pixelSize(points: CGSize(width: width, height: height))
        )
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
        AsyncImageView(
            url: url,
            contentMode: .fill,
            targetPixelSize: ImageSizing.pixelSize(
                points: CGSize(width: UIScreen.main.bounds.width, height: height)
            )
        )
            .frame(height: height)
            .clipped()
    }
}

// MARK: - Sizing helper

/// Converts point-space sizes into pixel-space sizes for ImageIO downsampling.
/// On Apple TV 1080p `nativeScale` is 1.0; on Apple TV 4K it's 2.0. Using pixel
/// space means 4K displays get crisp images while 1080p displays don't pay the
/// 4K memory tax.
enum ImageSizing {
    static func pixelSize(points: CGSize) -> CGSize {
        let scale = UIScreen.main.nativeScale
        return CGSize(width: points.width * scale, height: points.height * scale)
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
