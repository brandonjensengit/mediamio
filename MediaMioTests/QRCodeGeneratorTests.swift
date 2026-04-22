//
//  QRCodeGeneratorTests.swift
//  MediaMioTests
//
//  Locks the QRCodeGenerator contract — we render these in a sheet at
//  runtime with no fallback text for the happy path, so a silent regression
//  (CoreImage API change, payload encoding bug) would blank the handoff UI
//  with no user-visible error. These tests make that fail CI instead.
//

import Testing
import Foundation
import UIKit
@testable import MediaMio

struct QRCodeGeneratorTests {

    @Test
    func emptyPayloadReturnsNil() {
        #expect(QRCodeGenerator.image(for: "") == nil)
    }

    @Test
    func shortURLProducesScannableImage() throws {
        let image = try #require(
            QRCodeGenerator.image(for: "https://example.com/", targetSide: 600)
        )
        // targetSide is a minimum — nearest-neighbor scaling only goes up, never
        // down, so the produced image should meet or exceed the request.
        #expect(image.size.width >= 600)
        #expect(image.size.height >= 600)
        #expect(image.size.width == image.size.height)  // QR is square
    }

    @Test
    func largerTargetSideProducesLargerImage() throws {
        let small = try #require(
            QRCodeGenerator.image(for: "https://example.com/a", targetSide: 300)
        )
        let large = try #require(
            QRCodeGenerator.image(for: "https://example.com/a", targetSide: 900)
        )
        #expect(large.size.width > small.size.width)
    }

    @Test
    func typicalJellyfinHandoffURLEncodes() throws {
        let url = "https://jellyfin.home.lan:8096/web/index.html#/details?id=abc123def456"
        let image = try #require(QRCodeGenerator.image(for: url, targetSide: 600))
        #expect(image.size.width > 0)
    }

    @Test
    func realisticLongURLStillEncodes() throws {
        // Real-world worst case: an external link with a long tracking query
        // string. QR Version 40-H tops out around 1273 bytes in byte mode —
        // any realistic media URL stays well under that. 800 chars keeps us
        // safely inside the envelope.
        let longPath = String(repeating: "a", count: 800)
        let url = "https://example.com/\(longPath)"
        let image = try #require(QRCodeGenerator.image(for: url, targetSide: 600))
        #expect(image.size.width > 0)
    }

    @Test
    func oversizedPayloadFailsGracefully() {
        // Above QR spec capacity — we want nil back, not a crash. This is the
        // contract the QRHandoffView relies on to show its fallback text.
        let oversized = String(repeating: "a", count: 5000)
        #expect(QRCodeGenerator.image(for: oversized) == nil)
    }
}
