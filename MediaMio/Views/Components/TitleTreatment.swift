//
//  TitleTreatment.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

/// Renders the transparent-PNG title logo Jellyfin serves via the `Logo`
/// image endpoint. Falls back to typographic text when no logo tag exists.
/// Shared by `HeroBanner` and `DetailHeaderView` so both cinematic surfaces
/// use the same logo/text fallback contract.
///
/// Kept as a separate View struct so the image loader state (image cached
/// vs pending) doesn't rebuild the surrounding content overlay on each
/// transition.
struct TitleTreatment: View {
    let item: MediaItem
    let baseURL: String
    var maxWidth: CGFloat = 600
    var maxHeight: CGFloat = 180
    var textFontSize: CGFloat = 60
    var alignment: Alignment = .leading

    @StateObject private var loader = ImageLoader()
    @State private var attemptedLoad = false

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: alignment)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
            } else {
                // Scale the desired cinematic size (60pt hero / 72pt detail)
                // against UIFontMetrics so tvOS Accessibility → Larger Text
                // still applies. Fixed `.system(size:)` would ignore the
                // accessibility scale entirely. tvOS has no `.largeTitle`
                // text style (iOS-only); `.title1` is the largest tvOS
                // surface-size class and is the right reference here.
                let scaledSize = UIFontMetrics(forTextStyle: .title1)
                    .scaledValue(for: textFontSize)
                Text(item.name)
                    .font(.system(size: scaledSize, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .shadow(color: .black.opacity(0.5), radius: 10)
            }
        }
        .onAppear {
            guard !attemptedLoad,
                  let url = item.logoImageURL(
                      baseURL: baseURL,
                      maxWidth: Int(maxWidth * UIScreen.main.nativeScale),
                      quality: Constants.UI.imageQuality
                  )
            else { return }
            attemptedLoad = true
            loader.load(
                from: url,
                targetPixelSize: CGSize(
                    width: maxWidth * UIScreen.main.nativeScale,
                    height: maxHeight * UIScreen.main.nativeScale
                )
            )
        }
    }
}
