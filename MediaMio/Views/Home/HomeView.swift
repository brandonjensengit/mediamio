//
//  HomeView.swift
//  MediaMio
//
//  Created by Claude Code
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Success state
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("Successfully Connected!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    if let session = authService.currentSession {
                        VStack(spacing: 12) {
                            Text("Welcome, \(session.user.name)")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("Server: \(session.serverURL)")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text("Phase 1 Complete!")
                        .font(.title2)
                        .foregroundColor(Constants.Colors.primary)
                        .padding(.top, 20)

                    Text("Home screen with content coming in Phase 2")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Sign out button
                FocusableButton(title: "Sign Out", style: .destructive) {
                    authService.logout()
                }
                .frame(width: 500)
                .padding(.bottom, 40)
            }
            .padding(Constants.UI.defaultPadding)
        }
    }
}

#Preview {
    HomeView()
}
