//
//  YearRangePickerModal.swift
//  MediaMio
//
//  Year range picker modal for library filtering
//

import SwiftUI

struct YearRangePickerModal: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startYear: Int?
    @State private var endYear: Int?

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case startYear
        case endYear
        case preset(String)
        case clear
        case apply
    }

    // Year presets
    private let presets: [(String, Int?, Int?)] = [
        ("2020s", 2020, nil),
        ("2010s", 2010, 2019),
        ("2000s", 2000, 2009),
        ("1990s", 1990, 1999),
        ("1980s", 1980, 1989),
        ("1970s", 1970, 1979)
    ]

    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
        _startYear = State(initialValue: viewModel.filters.yearRange?.start)
        _endYear = State(initialValue: viewModel.filters.yearRange?.end)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                HStack {
                    Text("Select Year Range")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Clear") {
                        startYear = nil
                        endYear = nil
                    }
                    .buttonStyle(.card)
                    .focused($focusedField, equals: .clear)

                    Button("Apply") {
                        applyYearRange()
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($focusedField, equals: .apply)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // Year Range Pickers
                VStack(spacing: 30) {
                    HStack(spacing: 40) {
                        // Start Year
                        YearPickerColumn(
                            title: "From Year",
                            selectedYear: $startYear,
                            availableYears: viewModel.availableYears,
                            isFocused: focusedField == .startYear
                        )
                        .focused($focusedField, equals: .startYear)

                        // End Year
                        YearPickerColumn(
                            title: "To Year",
                            selectedYear: $endYear,
                            availableYears: viewModel.availableYears,
                            isFocused: focusedField == .endYear
                        )
                        .focused($focusedField, equals: .endYear)
                    }
                    .frame(height: 300)

                    // Presets
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Presets")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                            ForEach(presets, id: \.0) { preset in
                                PresetButton(
                                    title: preset.0,
                                    isSelected: startYear == preset.1 && endYear == preset.2
                                ) {
                                    startYear = preset.1
                                    endYear = preset.2
                                }
                                .focused($focusedField, equals: .preset(preset.0))
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                }

                Spacer()
            }
        }
        .onAppear {
            focusedField = .startYear
        }
    }

    private func applyYearRange() {
        if startYear != nil || endYear != nil {
            viewModel.filters.yearRange = YearRange(start: startYear, end: endYear)
        } else {
            viewModel.filters.yearRange = nil
        }

        Task {
            await viewModel.applyFilters()
            dismiss()
        }
    }
}

// MARK: - Year Picker Column

struct YearPickerColumn: View {
    let title: String
    @Binding var selectedYear: Int?
    let availableYears: [Int]
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Picker(title, selection: $selectedYear) {
                Text("Any").tag(nil as Int?)
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year as Int?)
                }
            }
            .pickerStyle(.automatic)
            .frame(width: 200, height: 250)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isFocused ? 0.15 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.white : Color.clear, lineWidth: 3)
            )
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor, lineWidth: 2)
                )
                .scaleEffect(isFocused ? 1.05 : 1.0)
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
