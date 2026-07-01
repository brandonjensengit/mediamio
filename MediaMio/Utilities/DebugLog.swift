//
//  DebugLog.swift
//  MediaMio
//
//  Log channels routed to os.log (subsystem com.mediamio) so output is
//  filterable in Console/log stream. `@autoclosure` defers string
//  interpolation; debug-level messages are not persisted in release.
//
//    DebugLog.verbose(...)    // lifecycle / general one-shot diagnostics
//    DebugLog.playback(...)   // AVPlayer, streaming, player VC creation
//    DebugLog.focus(...)      // focus-engine diagnostics
//

import Foundation
import os

enum DebugLog {
    private static let verboseLogger = Logger(subsystem: "com.mediamio", category: "verbose")
    private static let playbackLogger = Logger(subsystem: "com.mediamio", category: "playback")
    private static let focusLogger = Logger(subsystem: "com.mediamio", category: "focus")

    static func verbose(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        verboseLogger.debug("\(text)")
        #endif
    }

    static func playback(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        playbackLogger.debug("\(text)")
        #endif
    }

    static func focus(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        focusLogger.debug("\(text)")
        #endif
    }
}
