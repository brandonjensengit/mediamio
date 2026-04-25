//
//  SplashSignposts.swift
//  MediaMio
//
//  os_signpost helper for cold-launch splash timing. The audit asked us to
//  measure the splash floor (currently 2000ms) against the actual data-ready
//  time before deciding whether to lower it. These signposts feed Instruments
//  → Points of Interest so we can plot the distribution across N cold launches.
//
//  Constraint: this file does NOT change splash behavior. It only emits
//  signposts. The decision (lower the floor / make it adaptive / leave as-is)
//  is gated on what the measurement reports, per audit §6 #2.
//
//  Three landmarks plus one wrapper interval:
//    - Splash interval begin     → SplashScreenView.onAppear
//    - "Content Loaded"  event   → appState.contentLoaded set true
//    - "Minimum Floor"   event   → minimumTimeElapsed set true (2s elapsed)
//    - Splash interval end       → isActive flipped false (overlay dismissed)
//

import Foundation
import os

enum SplashSignposts {
    static let signposter = OSSignposter(
        subsystem: "com.mediamio.app",
        category: "SplashTiming"
    )
}
