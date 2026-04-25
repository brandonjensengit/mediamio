//
//  TrackedPushedView.swift
//  MediaMio
//
//  ViewModifier that increments `NavigationManager.pushedViewCount` for the
//  lifetime of a pushed destination view. Used by Settings sub-screens so
//  the top-level Menu-button handler in `MainTabView` knows a NavigationStack
//  has a pushed view on screen and yields to the stack's own pop behavior.
//
//  Without this, Menu on a sub-screen like Playback Settings would skip the
//  Settings list and jump straight to the Home tab — because `MainTabView`
//  only knows a push is in flight via this counter.
//

import SwiftUI

private struct TrackedPushedViewModifier: ViewModifier {
    @EnvironmentObject private var navigationManager: NavigationManager

    func body(content: Content) -> some View {
        content
            .onAppear    { navigationManager.registerPushedView() }
            .onDisappear { navigationManager.unregisterPushedView() }
    }
}

extension View {
    /// Apply on the root of any NavigationStack destination view so Menu
    /// pops the stack (instead of MainTabView's handler switching tabs).
    func trackedPushedView() -> some View {
        modifier(TrackedPushedViewModifier())
    }
}
