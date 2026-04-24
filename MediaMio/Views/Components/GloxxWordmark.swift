//
//  GloxxWordmark.swift
//  MediaMio
//
//  Typographic wordmark for the Gloxx brand. Uses Space Grotesk Bold
//  with wide tracking + uppercase — matches the treatment on gloxx.ai
//  (`.nav-logo` → `font-family: 'Space Grotesk'; font-weight: 700;
//  letter-spacing: .25em; text-transform: uppercase`).
//
//  Replaces the earlier `Image("AppLogo")` PNG wordmark everywhere a
//  text-only brand lockup is called for — splash, top nav, loading
//  view, auth headers.
//

import SwiftUI

struct GloxxWordmark: View {
    /// Visual size of the wordmark (cap height in points). Passed straight
    /// to the custom font so the caller controls scale per surface.
    var size: CGFloat = 60
    var color: Color = .white

    var body: some View {
        Text("GLOXX")
            .font(.custom("SpaceGrotesk-Bold", size: size))
            .tracking(size * 0.25)
            .foregroundColor(color)
            .accessibilityLabel("Gloxx")
    }
}

#Preview {
    VStack(spacing: 40) {
        GloxxWordmark(size: 28)
        GloxxWordmark(size: 60)
        GloxxWordmark(size: 120)
    }
    .padding(60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Constants.Colors.background)
}
