//
//  GenrePickerModal.swift
//  MediaMio
//
//  Genre picker modal for library filtering
//

import SwiftUI

struct GenrePickerModal: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedGenre: Genre?

    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)
    ]

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                HStack {
                    Text("Select Genres")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    if !viewModel.filters.selectedGenres.isEmpty {
                        Button("Clear Selection") {
                            viewModel.filters.selectedGenres.removeAll()
                        }
                        .buttonStyle(.card)
                    }

                    Button("Done") {
                        Task {
                            await viewModel.applyFilters()
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // Genre Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.availableGenres) { genre in
                            GenreCard(
                                genre: genre,
                                isSelected: viewModel.filters.selectedGenres.contains(genre),
                                action: {
                                    toggleGenre(genre)
                                }
                            )
                            .focused($focusedGenre, equals: genre)
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Focus first genre
            focusedGenre = viewModel.availableGenres.first
        }
    }

    private func toggleGenre(_ genre: Genre) {
        if viewModel.filters.selectedGenres.contains(genre) {
            viewModel.filters.selectedGenres.remove(genre)
        } else {
            viewModel.filters.selectedGenres.insert(genre)
        }
    }
}

// MARK: - Genre Card Component

struct GenreCard: View {
    let genre: Genre
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            HStack {
                Text(genre.displayName)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.4)
        } else if isFocused {
            return Color.white.opacity(0.15)
        } else {
            return Color.white.opacity(0.05)
        }
    }

    private var borderColor: Color {
        if isFocused {
            return .white
        } else if isSelected {
            return .accentColor
        } else {
            return .clear
        }
    }
}
