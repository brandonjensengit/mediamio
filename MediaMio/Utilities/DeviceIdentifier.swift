//
//  DeviceIdentifier.swift
//  MediaMio
//
//  Single source of truth for the Jellyfin `DeviceId` value. Both the
//  authentication header (`X-Emby-Authorization`) and the playback stream
//  URL must use the **same** identifier, otherwise Jellyfin treats browsing
//  and playback as coming from two different devices and session attribution
//  / transcode bookkeeping breaks.
//
//  Constraint: this module never imports networking, AVKit, or the player.
//  It is a pure UIKit utility.
//

import Foundation
import UIKit

enum DeviceIdentifier {
    /// Returns a stable per-app device ID. Prefers `identifierForVendor`
    /// (stable across reinstalls for the same vendor on a real device) and
    /// falls back to a UserDefaults-backed UUID only when IFV is unavailable
    /// (simulator edge cases, pre-`UIScene` attach).
    ///
    /// The fallback key is shared with `JellyfinAPIClient`'s historical
    /// behavior so existing installs keep their ID across the unification
    /// — no one gets a "you're on a new device" prompt from the server.
    static func current() -> String {
        if let ifv = UIDevice.current.identifierForVendor?.uuidString {
            return ifv
        }
        if let saved = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.deviceId) {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Constants.UserDefaultsKeys.deviceId)
        return newId
    }
}
