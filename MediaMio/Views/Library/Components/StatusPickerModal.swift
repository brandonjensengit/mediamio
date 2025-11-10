//
//  StatusPickerModal.swift
//  MediaMio
//
//  Watched/Unwatched status picker modal for library filtering
//

import SwiftUI

struct StatusPickerModal: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showWatched: Bool
    @State private var showUnwatched: Bool

    @FocusState private var focusedOption: StatusOption?

    enum StatusOption: Hashable {
        case watched
        case unwatched
        case apply
    }

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _showWatched = State(initialValue: viewModel.filters.showWatched)
        _showUnwatched = State(initialValue: viewModel.filters.showUnwatched)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Text("Watch Status")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Apply") {
                        applyStatus()
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($focusedOption, equals: .apply)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // Status Options
                VStack(spacing: 30) {
                    // Watched Toggle
                    StatusToggleCard(
                        icon: "checkmark.circle.fill",
                        title: "Watched",
                        description: "Show items you've already watched",
                        isEnabled: showWatched,
                        action: {
                            showWatched.toggle()
                        }
                    )
                    .focused($focusedOption, equals: .watched)

                    // Unwatched Toggle
                    StatusToggleCard(
                        icon: "circle",
                        title: "Unwatched",
                        description: "Show items you haven't watched yet",
                        isEnabled: showUnwatched,
                        action: {
                            showUnwatched.toggle()
                        }
                    )
                    .focused($focusedOption, equals: .unwatched)
                }
                .padding(.horizontal, 60)

                // Info Text
                if !showWatched && !showUnwatched {
                    Text("⚠️ No items will be shown if both are disabled")
                        .font(.headline)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal, 60)
                }

                Spacer()
            }
        }
        .onAppear {
            focusedOption = .watched
        }
    }

    private func applyStatus() {
        viewModel.filters.showWatched = showWatched
        viewModel.filters.showUnwatched = showUnwatched

        Task {
            await viewModel.applyFilters()
            dismiss()
        }
    }
}

// MARK: - Status Toggle Card

struct StatusToggleCard: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .frame(width: 70)

                // Text Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isEnabled ? .white : .secondary)

                    Text(description)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Toggle Indicator
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)

                    if isEnabled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isFocused {
            return Color.white.opacity(0.15)
        } else if isEnabled {
            return Color.accentColor.opacity(0.2)
        } else {
            return Color.white.opacity(0.05)
        }
    }

    private var borderColor: Color {
        if isFocused {
            return .white
        } else if isEnabled {
            return .accentColor.opacity(0.5)
        } else {
            return .clear
        }
    }
}
