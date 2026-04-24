//
//  LoadingView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct LoadingView: View {
    let message: String
    let showLogo: Bool

    init(message: String = "Loading...", showLogo: Bool = false) {
        self.message = message
        self.showLogo = showLogo
    }

    var body: some View {
        VStack(spacing: 40) {
            if showLogo {
                GloxxWordmark(size: 90)
            }

            // Loading indicator
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            // Message
            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    LoadingView()
}
