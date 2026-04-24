//
//  FocusModifiers.swift
//  MediaMio
//
//  Two focus tiers applied via ViewModifier so every focusable surface in
//  the app has one of exactly two treatments:
//
//    • `.chromeFocus()`  — nav chips, settings rows, toolbar pills, sidebar
//                          rows. Subtle lift, no glow.
//    • `.contentFocus()` — posters, hero CTAs. Bigger lift + dark drop
//                          shadow (reads as depth on a dark background).
//
//  Both modifiers read `@Environment(\.isFocused)`, so they compose with
//  any `Button(.plain)` or `.focusable()` wrapper with no extra plumbing.
//  Tokens live in `Constants.UI.ChromeFocus` / `Constants.UI.ContentFocus`.
//

import SwiftUI

// MARK: - Chrome focus

/// Subtle focus lift for chrome surfaces. Never uses a white/color glow —
/// glows are reserved for content (posters), and only as dark drop shadows.
private struct ChromeFocusModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? Constants.UI.ChromeFocus.scale : 1.0)
            .offset(y: isFocused ? Constants.UI.ChromeFocus.yOffset : 0)
            .shadow(
                color: isFocused ? Constants.UI.ChromeFocus.shadowColor : .clear,
                radius: isFocused ? Constants.UI.ChromeFocus.shadowRadius : 0,
                x: 0,
                y: isFocused ? Constants.UI.ChromeFocus.shadowY : 0
            )
            .animation(Constants.UI.ChromeFocus.animation, value: isFocused)
    }
}

/// Environment-reading wrapper so callers inside a `Button(.plain)` label
/// can write `.chromeFocus()` without threading the focus state through.
private struct ChromeFocusEnvironmentModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content.modifier(ChromeFocusModifier(isFocused: isFocused))
    }
}

// MARK: - Content focus

/// Bigger focus lift for content surfaces. Dark drop shadow — never the
/// white-glow "AI card" look. Spring animation adds a touch of physicality
/// that chrome doesn't need.
private struct ContentFocusModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isFocused ? Constants.UI.ContentFocus.scale : 1.0)
            .offset(y: isFocused ? Constants.UI.ContentFocus.yOffset : 0)
            .shadow(
                color: isFocused ? Constants.UI.ContentFocus.shadowColor : .clear,
                radius: isFocused ? Constants.UI.ContentFocus.shadowRadius : 0,
                x: 0,
                y: isFocused ? Constants.UI.ContentFocus.shadowY : 0
            )
            .animation(Constants.UI.ContentFocus.animation, value: isFocused)
    }
}

private struct ContentFocusEnvironmentModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content.modifier(ContentFocusModifier(isFocused: isFocused))
    }
}

// MARK: - View sugar

extension View {
    /// Chrome focus tier. No-arg form reads `@Environment(\.isFocused)` —
    /// use when the caller sits inside a `Button(.plain)` label.
    func chromeFocus() -> some View {
        modifier(ChromeFocusEnvironmentModifier())
    }

    /// Chrome focus tier with an explicit focus flag — use when the caller
    /// drives focus with its own `@FocusState` and isn't inside a Button.
    func chromeFocus(isFocused: Bool) -> some View {
        modifier(ChromeFocusModifier(isFocused: isFocused))
    }

    /// Content focus tier. No-arg form reads `@Environment(\.isFocused)`.
    func contentFocus() -> some View {
        modifier(ContentFocusEnvironmentModifier())
    }

    /// Content focus tier with an explicit focus flag.
    func contentFocus(isFocused: Bool) -> some View {
        modifier(ContentFocusModifier(isFocused: isFocused))
    }
}
