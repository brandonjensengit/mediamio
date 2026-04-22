//
//  QRCodeGenerator.swift
//  MediaMio
//
//  CoreImage-backed QR generator for companion-device handoff. Given a URL
//  string, produces a crisp black-on-white UIImage sized for on-screen
//  scanning from ~2.5m (couch distance). High error-correction ("H") so the
//  code still resolves when photographed off-axis or with motion blur.
//
//  Constraint: never reaches the network, never loads from disk, and never
//  imports SwiftUI. This is a pure pixel utility callable from any layer.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum QRCodeGenerator {
    /// Renders `payload` as a QR code image whose longest side is at least
    /// `targetSide` points. Returns `nil` if the payload is empty or if
    /// CoreImage fails to produce a cgImage (extremely large payloads can
    /// exceed QR spec limits).
    ///
    /// - Parameters:
    ///   - payload: The string to encode (typically a URL).
    ///   - targetSide: Desired minimum side length in points.
    static func image(for payload: String, targetSide: CGFloat = 600) -> UIImage? {
        guard !payload.isEmpty else { return nil }
        guard let data = payload.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "H"

        guard let rawImage = filter.outputImage else { return nil }

        // Nearest-neighbor scale: preserves hard module edges. Scanners require
        // sharp transitions — a Lanczos upscale would anti-alias them and kill
        // the code at smaller display sizes.
        let scale = max(1, targetSide / rawImage.extent.width)
        let scaled = rawImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
