//
//  SkeletonView.swift
//  MediaMio
//
//  Shimmering placeholder primitives used during first-paint loading states.
//  Keeping the skeleton *shape* close to the real content (hero + N poster rows)
//  means the user sees a stable layout during the network fetch instead of a
//  black screen, which measurably reduces perceived latency on slow networks.
//

import SwiftUI

/// A rounded-rect placeholder that animates a moving gradient. Public so other
/// screens (Detail, Library) can compose their own skeletons from the same tile.
struct ShimmerTile: View {
    var cornerRadius: CGFloat = Constants.UI.cardCornerRadius
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.05))
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.white.opacity(0.08), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 1.5)
                    .offset(x: phase * geometry.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

/// Full-screen skeleton for the Home initial load. Mirrors the hero + rows layout
/// HomeContentView renders once the real data arrives, so there's no layout shift
/// when the skeleton swaps for content.
struct HomeSkeletonView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero placeholder
                ShimmerTile(cornerRadius: 0)
                    .frame(height: Constants.UI.heroBannerHeight)

                // Row placeholders
                VStack(spacing: Constants.UI.sectionSpacing) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
                .padding(.top, 40)
                .padding(.leading, 80)
                .padding(.bottom, 60)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

/// A horizontal strip of poster-shaped shimmer tiles. Not individually focusable —
/// the real content's focus engine takes over once loading finishes.
private struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section title placeholder
            ShimmerTile(cornerRadius: 6)
                .frame(width: 300, height: 28)

            // Poster row
            HStack(spacing: Constants.UI.rowSpacing / 3) {
                ForEach(0..<6, id: \.self) { _ in
                    ShimmerTile()
                        .frame(width: Constants.UI.posterWidth, height: Constants.UI.posterHeight)
                }
            }
        }
    }
}

#Preview {
    HomeSkeletonView()
}
