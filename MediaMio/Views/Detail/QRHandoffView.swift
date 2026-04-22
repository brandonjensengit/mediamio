//
//  QRHandoffView.swift
//  MediaMio
//
//  Companion-device handoff sheet. Shows a large QR code on the left and
//  the destination title + URL on the right so the viewer can scan with a
//  phone and continue on another device. Used for both external links
//  (IMDb, TMDB, etc.) and "open on another device" from the Detail screen.
//
//  Dismisses via the Siri Remote Menu button — tvOS's default sheet
//  behavior, no custom close affordance needed.
//

import SwiftUI

struct QRHandoffView: View {
    let title: String
    let subtitle: String?
    let url: String

    @Environment(\.dismiss) private var dismiss

    private var qrImage: UIImage? {
        QRCodeGenerator.image(for: url, targetSide: 900)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 80) {
                // QR code
                Group {
                    if let image = qrImage {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        // Fallback: URL text large enough to type on a phone
                        // manually. Not great, but better than a blank sheet.
                        Text(url)
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .frame(width: 600, height: 600)
                .padding(40)
                .background(Color.white)
                .cornerRadius(24)

                // Metadata
                VStack(alignment: .leading, spacing: 24) {
                    Text("Scan to continue on your phone")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.6))

                    Text(title)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(3)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(4)
                    }

                    Spacer().frame(height: 20)

                    Text(url)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Text("Press Menu to close")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 20)
                }
                .frame(maxWidth: 800, alignment: .leading)
            }
            .padding(.horizontal, 80)
        }
    }
}

#Preview {
    QRHandoffView(
        title: "The Matrix Reloaded",
        subtitle: "Continue watching on another device",
        url: "https://jellyfin.example.com/web/index.html#/details?id=abc123"
    )
}
