//
//  ParentalControls.swift
//  MediaMio
//
//  Content-rating model + filter logic for parental controls.
//  Never imports SwiftUI, AVFoundation, or HTTP types — pure domain logic
//  so `ContentRatingTests` can exercise it without the app running.
//

import Foundation

// MARK: - Content Rating Level

/// User-facing "max allowed content" tiers. Each tier is a bucket that covers
/// several wire-format rating strings (US movies + US TV + a few common
/// international equivalents). The user picks a tier; we translate to
/// server/client filter predicates from there.
enum ContentRatingLevel: String, CaseIterable, Identifiable, Codable {
    /// G, TV-Y, TV-G only. Suitable for small children.
    case familyOnly = "Family Only"

    /// Family + PG, TV-Y7, TV-PG. Suitable for kids with supervision.
    case kids = "Kids"

    /// Kids + PG-13, TV-14. Suitable for teens.
    case teen = "Teen"

    /// Teen + R, TV-MA. Excludes only NC-17 / X-rated / unrated content.
    case mature = "Mature"

    var id: String { rawValue }

    /// Higher rank = more permissive. Used for comparing an item's rating
    /// against the ceiling. Step size of 10 leaves room for intermediate
    /// tiers if we ever need them.
    var rank: Int {
        switch self {
        case .familyOnly: return 10
        case .kids:       return 20
        case .teen:       return 30
        case .mature:     return 40
        }
    }

    /// What we send as Jellyfin's `MaxOfficialRating` query parameter.
    /// This is the *most permissive* US movie rating at this tier — the
    /// server will filter anything with a higher configured score.
    ///
    /// Note: this is only a first-line filter. The server's filter depends
    /// on the admin's Parental Rating Score configuration, which may be
    /// incomplete. We also run `ContentRating.isAllowed(...)` client-side
    /// so items with unmapped or absent `OfficialRating` get hidden.
    var jellyfinMaxRating: String {
        switch self {
        case .familyOnly: return "G"
        case .kids:       return "PG"
        case .teen:       return "PG-13"
        case .mature:     return "R"
        }
    }

    var description: String {
        switch self {
        case .familyOnly: return "G, TV-Y, TV-G"
        case .kids:       return "Up to PG, TV-PG"
        case .teen:       return "Up to PG-13, TV-14"
        case .mature:     return "Up to R, TV-MA"
        }
    }
}

// MARK: - Rating String → Rank

/// Normalizes Jellyfin's `OfficialRating` string into a rank on the same
/// scale as `ContentRatingLevel.rank`. Ratings we don't recognize return
/// `nil`, which the filter treats as *blocked* — we'd rather hide an
/// indie/foreign film with an unfamiliar certification than let something
/// adult through with a string we failed to parse.
enum ContentRating {

    /// Returns a rank ≤ the matching `ContentRatingLevel.rank` when the item
    /// fits entirely inside that tier. Unknown ratings return `nil`.
    static func rank(for officialRating: String?) -> Int? {
        guard let raw = officialRating?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return nil
        }
        let normalized = raw.uppercased()

        // Movies — US MPAA. Ordered by restrictiveness.
        if ["G"].contains(normalized)          { return 5 }
        if ["PG"].contains(normalized)         { return 15 }
        if ["PG-13"].contains(normalized)      { return 25 }
        if ["R"].contains(normalized)          { return 35 }
        if ["NC-17", "X"].contains(normalized) { return 100 }

        // TV — US.
        if ["TV-Y"].contains(normalized)   { return 5 }
        if ["TV-Y7"].contains(normalized)  { return 15 }
        if ["TV-G"].contains(normalized)   { return 10 }
        if ["TV-PG"].contains(normalized)  { return 18 }
        if ["TV-14"].contains(normalized)  { return 28 }
        if ["TV-MA"].contains(normalized)  { return 38 }

        // Approved / Not-Rated / Unrated — treat as unknown so the filter
        // hides them. Users who want these can widen the tier to `mature`
        // and disable controls.

        return nil
    }

    /// Is `officialRating` allowed under the `level` tier?
    /// Unknown / missing ratings are **not** allowed when controls are on —
    /// this is the defense-in-depth posture.
    static func isAllowed(officialRating: String?, under level: ContentRatingLevel) -> Bool {
        guard let itemRank = rank(for: officialRating) else {
            return false
        }
        return itemRank <= level.rank
    }
}

// MARK: - Runtime Config

/// Snapshot of the user's current parental-controls preferences. Services
/// read `current` at the call site rather than holding a long-lived
/// reference, so toggle changes take effect on the next fetch.
///
/// Why a struct, not a singleton? Services should not carry write access
/// to settings — they only read. A value type makes that explicit and
/// makes the behavior trivially testable (just construct one).
struct ParentalControlsConfig: Equatable {
    let isEnabled: Bool
    let maxLevel: ContentRatingLevel

    /// Read the live config from `UserDefaults.standard`. Matches the keys
    /// `SettingsManager` writes via `@AppStorage`.
    static var current: ParentalControlsConfig {
        let enabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        let raw = UserDefaults.standard.string(forKey: Keys.maxRating)
            ?? ContentRatingLevel.teen.rawValue
        let level = ContentRatingLevel(rawValue: raw) ?? .teen
        return ParentalControlsConfig(isEnabled: enabled, maxLevel: level)
    }

    /// The value to send as `MaxOfficialRating` on Jellyfin queries, or nil
    /// when parental controls are off (don't filter at all).
    var jellyfinMaxRating: String? {
        isEnabled ? maxLevel.jellyfinMaxRating : nil
    }

    /// Apply the client-side defense-in-depth filter to a list of items.
    /// When disabled, returns the list unchanged.
    func filter(_ items: [MediaItem]) -> [MediaItem] {
        guard isEnabled else { return items }
        return items.filter {
            ContentRating.isAllowed(officialRating: $0.officialRating, under: maxLevel)
        }
    }

    enum Keys {
        static let enabled = "parentalControlsEnabled"
        static let maxRating = "parentalControlsMaxRating"
    }
}
