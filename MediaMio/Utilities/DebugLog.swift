//
//  DebugLog.swift
//  MediaMio
//
//  Debug-only log channels. The bodies compile out in release builds and
//  `@autoclosure` defers string interpolation so call sites cost nothing —
//  no `#if DEBUG` guards needed at the caller.
//
//    DebugLog.verbose(...)    // lifecycle / general one-shot diagnostics
//    DebugLog.playback(...)   // AVPlayer, streaming, player VC creation
//    DebugLog.focus(...)      // focus-engine diagnostics
//
//  Channels are separated so a future version can route them to os_log
//  subsystems without touching call sites.
//

import Foundation

enum DebugLog {
    static func verbose(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }

    static func playback(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }

    static func focus(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}
