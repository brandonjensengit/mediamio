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
                // Logo and branding
                VStack(spacing: 30) {
                    // App Logo
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)

                    // Logo Text
                    Image("LogoText")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 400)
                }
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
