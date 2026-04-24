//
//  LibraryToolbar.swift
//  MediaMio
//
//  Toolbar for library view with sort and search
//

import SwiftUI

struct LibraryToolbar: View {
    @ObservedObject var viewModel: LibraryViewModel

    @FocusState.Binding var focusedField: ToolbarField?

    enum ToolbarField: Hashable {
        case sort
    }

    var body: some View {
        HStack(spacing: 30) {
            // Title and item count
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(viewModel.statusText)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sort Button — note: `Menu { ... } label: { MenuChip(...) }` isn't
            // directly usable because `Menu.label` expects a View, not a
            // Button. Wrap the chip's HStack inline for the menu trigger so
            // tvOS's native menu presentation works, but keep visuals identical
            // to the `MenuChip` component.
            Menu {
                ForEach(LibraryViewModel.SortOption.allCases) { option in
                    Button(action: {
                        Task {
                            await viewModel.changeSortOption(option)
                        }
                    }) {
                        HStack {
                            Text(option.displayName)
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort: \(viewModel.sortOption.displayName)")
                    Image(systemName: "chevron.down")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Constants.Colors.surface1)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .chromeFocus()
            .focused($focusedField, equals: .sort)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .focusSection()  // Keep focus within toolbar section
    }
}
