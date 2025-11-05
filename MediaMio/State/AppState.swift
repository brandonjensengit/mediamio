//
//  AppState.swift
//  MediaMio
//
//  Global app state management
//

import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isLaunching = true
    @Published var jellyfinConnected = false
    @Published var contentLoaded = false
}
