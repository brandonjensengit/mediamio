//
//  HomeLayoutSettingsView.swift
//  MediaMio
//
//  Lets the user reorder, hide, and restore Home page rows. Each visible
//  row is one focusable Button; Select opens a confirmationDialog with the
//  Move Up / Move Down / Hide actions. Hidden rows restore with one tap.
//
//  We intentionally avoid SwiftUI's `Menu { } label: { }` wrapper here —
//  on tvOS, when a `Menu` is used as a row trigger inside a NavigationStack
//  the system's Menu-button routing gets confused (Menu button stops popping
//  the NavigationStack and instead exits the app). `confirmationDialog` is
//  the idiomatic tvOS primitive for this shape and plays nicely with
//  NavigationStack back-navigation.
//

import SwiftUI

struct HomeLayoutSettingsView: View {
    @ObservedObject private var store = HomeLayoutStore.shared
    @State private var actionTarget: HomeRowDescriptor? = nil
    @State private var showResetAlert = false

    private var visibleRows: [HomeRowDescriptor] {
        applyOrdering(store.knownRows.filter { !store.preferences.hiddenRowKeys.contains($0.key) })
    }

    private var hiddenRows: [HomeRowDescriptor] {
        store.knownRows.filter { store.preferences.hiddenRowKeys.contains($0.key) }
    }

    private var actionTargetIndex: Int? {
        guard let key = actionTarget?.key else { return nil }
        return visibleRows.firstIndex(where: { $0.key == key })
    }

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            if store.knownRows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        visibleSection
                        if !hiddenRows.isEmpty {
                            hiddenSection
                        }
                        resetSection
                    }
                    .padding(.horizontal, 80)
                    .padding(.vertical, 40)
                }
            }
        }
        .navigationTitle("Home Layout")
        .trackedPushedView()
        .confirmationDialog(
            actionTarget?.title ?? "Row Actions",
            isPresented: Binding(
                get: { actionTarget != nil },
                set: { if !$0 { actionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let row = actionTarget, let idx = actionTargetIndex {
                if idx > 0 {
                    Button {
                        withAnimation(.snappy) { store.moveUp(key: row.key) }
                        actionTarget = nil
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                }
                if idx < visibleRows.count - 1 {
                    Button {
                        withAnimation(.snappy) { store.moveDown(key: row.key) }
                        actionTarget = nil
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                }
                Button(role: .destructive) {
                    withAnimation(.snappy) { store.hide(key: row.key) }
                    actionTarget = nil
                } label: {
                    Label("Hide Row", systemImage: "eye.slash")
                }
                Button("Cancel", role: .cancel) { actionTarget = nil }
            }
        }
        .alert("Reset Home Layout", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                withAnimation(.snappy) { store.reset() }
            }
        } message: {
            Text("Restores the default row order and unhides every row.")
        }
    }

    // MARK: - Visible

    @ViewBuilder
    private var visibleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Visible Rows")
            VStack(spacing: 12) {
                ForEach(Array(visibleRows.enumerated()), id: \.element.id) { idx, row in
                    Button {
                        actionTarget = row
                    } label: {
                        rowLabel(
                            title: row.title,
                            accessory: "\(idx + 1) of \(visibleRows.count)",
                            trailingIcon: "ellipsis.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            sectionFooter("Select a row to reorder or hide it. Hidden rows return at the bottom of the list when restored.")
        }
    }

    // MARK: - Hidden

    @ViewBuilder
    private var hiddenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Hidden Rows")
            VStack(spacing: 12) {
                ForEach(hiddenRows) { row in
                    Button {
                        withAnimation(.snappy) { store.show(key: row.key) }
                    } label: {
                        rowLabel(
                            title: row.title,
                            accessory: "Hidden",
                            trailingIcon: "plus.circle.fill",
                            dimmed: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            sectionFooter("Select a hidden row to restore it.")
        }
    }

    // MARK: - Reset

    @ViewBuilder
    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                showResetAlert = true
            } label: {
                rowLabel(
                    title: "Reset to Default",
                    accessory: nil,
                    trailingIcon: "arrow.counterclockwise",
                    destructive: true
                )
            }
            .buttonStyle(.plain)
            sectionFooter("Restores the server's row order and unhides every row.")
        }
    }

    // MARK: - Empty

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.4))
            Text("Home rows aren't loaded yet")
                .font(.title3)
                .foregroundColor(.white)
            Text("Open the Home tab to populate this list.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 600, alignment: .center)
        .padding(60)
    }

    // MARK: - Building blocks

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.5))
            .tracking(1.2)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white.opacity(0.5))
    }

    private func rowLabel(title: String,
                          accessory: String?,
                          trailingIcon: String,
                          dimmed: Bool = false,
                          destructive: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(destructive ? .orange : (dimmed ? .white.opacity(0.6) : .white))

            Spacer()

            if let accessory {
                Text(accessory)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
            }

            Image(systemName: trailingIcon)
                .font(.title3)
                .foregroundColor(destructive ? .orange : Constants.Colors.accent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(minHeight: 80)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }

    // MARK: - Helpers

    /// Sort visible rows by `preferences.rowOrder`; rows not in `rowOrder`
    /// fall to the bottom in `knownRows` order. Mirrors `applyLayout` so
    /// what the user sees in Settings matches what they see on Home.
    private func applyOrdering(_ rows: [HomeRowDescriptor]) -> [HomeRowDescriptor] {
        let order = store.preferences.rowOrder
        guard !order.isEmpty else { return rows }
        var byKey: [String: HomeRowDescriptor] = [:]
        for row in rows { byKey[row.key] = row }
        var seen: Set<String> = []
        var result: [HomeRowDescriptor] = []
        for key in order {
            if let row = byKey[key] {
                result.append(row)
                seen.insert(key)
            }
        }
        for row in rows where !seen.contains(row.key) {
            result.append(row)
        }
        return result
    }
}

#Preview {
    NavigationStack {
        HomeLayoutSettingsView()
    }
}
