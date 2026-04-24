//
//  LibraryFilterBar.swift
//  MediaMio
//
//  Horizontal filter bar for tvOS library browsing.
//
//  Each filter chip is a native tvOS `Menu` — a compact overlay list
//  anchored to the chip, triggered only on an explicit Select press.
//  Replaces the previous `sheet(isPresented:)` pattern that presented
//  a fullscreen modal on *focus arrival*, which made the filter row
//  feel sticky and unusable.
//

import SwiftUI

struct LibraryFilterBar: View {
    @ObservedObject var viewModel: LibraryViewModel

    // Available Rating steps — matches RatingPickerModal's set.
    private let ratingSteps: [Double] = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5]

    // Decade presets for Year filter. Custom start/end ranges aren't
    // surfaced here (they live in the legacy YearRangePickerModal, now
    // unreferenced); decades cover the 95% use case and fit a Menu.
    private let yearPresets: [(label: String, start: Int?, end: Int?)] = [
        ("2020s", 2020, nil),
        ("2010s", 2010, 2019),
        ("2000s", 2000, 2009),
        ("1990s", 1990, 1999),
        ("1980s", 1980, 1989),
        ("1970s", 1970, 1979)
    ]

    var body: some View {
        HStack(spacing: 20) {
            genreMenu
            yearMenu
            ratingMenu

            if viewModel.filters.isActive {
                Button {
                    Task { await viewModel.clearFilters() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear All")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .focusSection()
    }

    // MARK: - Genre menu (multi-select)

    private var genreMenu: some View {
        Menu {
            // "Clear" row — only useful when something is selected
            if !viewModel.filters.selectedGenres.isEmpty {
                Button(role: .destructive) {
                    viewModel.filters.selectedGenres.removeAll()
                    Task { await viewModel.applyFilters() }
                } label: {
                    Label("Clear Genres", systemImage: "xmark.circle")
                }
            }

            // One toggle-button per available genre. tvOS dismisses the
            // Menu on tap so multi-select requires reopening between
            // choices — still less intrusive than a fullscreen sheet,
            // and matches the Apple TV app pattern for categorical filters.
            ForEach(viewModel.availableGenres) { genre in
                Button {
                    toggleGenre(genre)
                } label: {
                    Label(
                        genre.displayName,
                        systemImage: viewModel.filters.selectedGenres.contains(genre)
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                }
            }
        } label: {
            FilterButton(
                title: "Genre",
                value: genreFilterText,
                isActive: !viewModel.filters.selectedGenres.isEmpty
            )
        }
    }

    // MARK: - Year menu (decade presets, single-select)

    private var yearMenu: some View {
        Menu {
            Button {
                viewModel.filters.yearRange = nil
                Task { await viewModel.applyFilters() }
            } label: {
                Label(
                    "Any Year",
                    systemImage: viewModel.filters.yearRange == nil ? "checkmark" : ""
                )
            }

            ForEach(yearPresets, id: \.label) { preset in
                Button {
                    viewModel.filters.yearRange = YearRange(start: preset.start, end: preset.end)
                    Task { await viewModel.applyFilters() }
                } label: {
                    Label(
                        preset.label,
                        systemImage: isYearPresetSelected(preset) ? "checkmark" : ""
                    )
                }
            }
        } label: {
            FilterButton(
                title: "Year",
                value: viewModel.filters.yearRange?.displayText ?? "Any",
                isActive: viewModel.filters.yearRange != nil
            )
        }
    }

    // MARK: - Rating menu (single-select)

    private var ratingMenu: some View {
        Menu {
            Button {
                viewModel.filters.minimumRating = 0
                Task { await viewModel.applyFilters() }
            } label: {
                Label(
                    "Any Rating",
                    systemImage: viewModel.filters.minimumRating == 0 ? "checkmark" : ""
                )
            }

            ForEach(ratingSteps, id: \.self) { step in
                Button {
                    viewModel.filters.minimumRating = step
                    Task { await viewModel.applyFilters() }
                } label: {
                    Label(
                        String(format: "★ %.1f+", step),
                        systemImage: viewModel.filters.minimumRating == step ? "checkmark" : ""
                    )
                }
            }
        } label: {
            FilterButton(
                title: "Rating",
                value: ratingFilterText,
                isActive: viewModel.filters.minimumRating > 0
            )
        }
    }

    // MARK: - Helpers

    private func toggleGenre(_ genre: Genre) {
        if viewModel.filters.selectedGenres.contains(genre) {
            viewModel.filters.selectedGenres.remove(genre)
        } else {
            viewModel.filters.selectedGenres.insert(genre)
        }
        Task { await viewModel.applyFilters() }
    }

    private func isYearPresetSelected(_ preset: (label: String, start: Int?, end: Int?)) -> Bool {
        guard let range = viewModel.filters.yearRange else { return false }
        return range.start == preset.start && range.end == preset.end
    }

    private var genreFilterText: String {
        let count = viewModel.filters.selectedGenres.count
        if count == 0 { return "All" }
        if count == 1 { return viewModel.filters.selectedGenres.first?.displayName ?? "All" }
        return "\(count) selected"
    }

    private var ratingFilterText: String {
        let rating = viewModel.filters.minimumRating
        return rating > 0 ? String(format: "%.1f+", rating) : "Any"
    }
}

// MARK: - Filter Button Component

struct FilterButton: View {
    let title: String
    let value: String
    let isActive: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .foregroundColor(isActive ? .white : .primary)
        }
        .frame(minWidth: 140)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var backgroundColor: Color {
        if isFocused {
            return Constants.Colors.surface3
        } else if isActive {
            return Color.accentColor.opacity(0.3)
        } else {
            return Constants.Colors.surface1
        }
    }
}
