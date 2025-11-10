//
//  RatingPickerModal.swift
//  MediaMio
//
//  Rating picker modal for library filtering
//

import SwiftUI

struct RatingPickerModal: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRating: Double

    @FocusState private var focusedRating: Double?

    // Rating options (0.0 = no filter, then 5.0 to 9.0 in 0.5 increments)
    private let ratingOptions: [Double] = [0.0, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5]

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _selectedRating = State(initialValue: viewModel.filters.minimumRating)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Text("Minimum Rating")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Clear") {
                        selectedRating = 0.0
                    }
                    .buttonStyle(.card)

                    Button("Apply") {
                        applyRating()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // Rating Display
                VStack(spacing: 16) {
                    if selectedRating > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 50))

                            Text(String(format: "%.1f", selectedRating))
                                .font(.system(size: 60, weight: .bold))
                                .foregroundColor(.white)

                            Text("+")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Any Rating")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Text("Show items rated at or above")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)

                // Rating Options Grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)],
                    spacing: 20
                ) {
                    ForEach(ratingOptions, id: \.self) { rating in
                        RatingOptionCard(
                            rating: rating,
                            isSelected: selectedRating == rating,
                            action: {
                                selectedRating = rating
                            }
                        )
                        .focused($focusedRating, equals: rating)
                    }
                }
                .padding(.horizontal, 60)

                Spacer()
            }
        }
        .onAppear {
            focusedRating = selectedRating == 0.0 ? ratingOptions.first : selectedRating
        }
    }

    private func applyRating() {
        viewModel.filters.minimumRating = selectedRating

        Task {
            await viewModel.applyFilters()
            dismiss()
        }
    }
}

// MARK: - Rating Option Card

struct RatingOptionCard: View {
    let rating: Double
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)

                        Text(String(format: "%.1f", rating))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .white : .primary)

                        Text("+")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Any")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 3)
            )
            .scaleEffect(isFocused ? 1.1 : 1.0)
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
