//
//  LibraryToolbar.swift
//  MediaMio
//
//  Toolbar for library view with sort and search
//

import SwiftUI

struct LibraryToolbar: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var showSearch: Bool

    @FocusState.Binding var focusedField: ToolbarField?

    enum ToolbarField: Hashable {
        case sort
        case search
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

            // Sort Button
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
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.card)
            .focused($focusedField, equals: .sort)

            // Search Button
            Button(action: {
                showSearch = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.card)
            .focused($focusedField, equals: .search)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
        .focusSection()  // Keep focus within toolbar section
    }
}
