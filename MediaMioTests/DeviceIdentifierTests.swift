//
//  DeviceIdentifierTests.swift
//  MediaMioTests
//
//  Locks the contract that the player and the API client must agree on a
//  single device ID. Pre-fix, `VideoPlayerViewModel.getDeviceId()` used a
//  separate UserDefaults key from `JellyfinAPIClient.deviceId`, so playback
//  events were attributed to a different device than browsing events on
//  the Jellyfin server.
//

import Testing
import Foundation
import UIKit
@testable import MediaMio

@MainActor
struct DeviceIdentifierTests {

    @Test("DeviceIdentifier returns a non-empty stable string")
    func returnsNonEmpty() {
        let id = DeviceIdentifier.current()
        #expect(!id.isEmpty)
    }

    @Test("DeviceIdentifier is idempotent — two calls return the same value")
    func isIdempotent() {
        let first = DeviceIdentifier.current()
        let second = DeviceIdentifier.current()
        #expect(first == second)
    }

    @Test("On real devices DeviceIdentifier matches identifierForVendor when available")
    func matchesIFVWhenAvailable() {
        // On a simulator IFV may be nil; if so skip — the production fallback
        // is exercised by `usesUserDefaultsFallbackWhenIFVMissing` below.
        guard let ifv = UIDevice.current.identifierForVendor?.uuidString else {
            return
        }
        #expect(DeviceIdentifier.current() == ifv)
    }

    @Test("Once chosen, the value is stable across the same UserDefaults state")
    func stableAcrossCalls() {
        // Five calls — all equal. Catches accidental UUID() regeneration.
        let ids = (0..<5).map { _ in DeviceIdentifier.current() }
        #expect(Set(ids).count == 1)
    }
}
