//
//  SettingsCardComponents.swift
//  MediaMio
//
//  Row primitives + a generic option-picker screen used across every
//  Settings sub-page. Built so each sub-screen reads as pure composition
//  on top of the AccountSettingsView visual vocabulary:
//    - ZStack > ScrollView > VStack(spacing: 32) with 80/40/80 padding
//    - inline 57pt heading, .navigationBarHidden(true)
//    - surface1 → surface3-on-focus card rows, 120pt min height,
//      .chromeFocus() lift, Constants.UI.cardCornerRadius
//
//  Constraint: nothing here knows about a specific setting key. These are
//  presentational shapes only — the call sites bind state and pass labels.
//

import SwiftUI

// MARK: - Card scaffolding

/// Wraps a settings sub-screen body with the standard background, scroll
/// view, padding, and inline heading. Every Settings sub-page should sit
/// inside this — it's the single source of truth for the page chrome that
/// `AccountSettingsView` established.
struct SettingsCardScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text(title)
                        .font(.system(size: 57, weight: .regular))
                        .foregroundColor(.white)

                    content()
                }
                .padding(.horizontal, 80)
                .padding(.top, 40)
                .padding(.bottom, 80)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Inline heading replaces the system nav title — without this the
        // system would render a translucent "Settings"-style large title on
        // top of our 57pt heading.
        .navigationBarHidden(true)
        .trackedPushedView()
    }
}

// MARK: - Section helpers

/// Section label sitting above a stack of card rows. Matches the 23pt
/// medium / 0.55-opacity treatment from Account's "Switch Account",
/// "Add Server", "Sign Out" labels.
struct SettingsSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 23, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .padding(.leading, 4)
    }
}

/// Helper text rendered below a card stack (was Form's `footer:` slot).
/// Sits at the same horizontal inset as the section label so the helper
/// copy aligns visually with both the label and the card edges.
struct SettingsSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.55))
            .padding(.leading, 4)
            .padding(.trailing, 4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Convenience composition: label + card stack + optional footer.
/// 95% of settings sections fit this shape.
struct SettingsSection<Content: View>: View {
    let label: String?
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(_ label: String? = nil,
         footer: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let label {
                SettingsSectionLabel(text: label)
            }
            VStack(spacing: 12) {
                content()
            }
            if let footer {
                SettingsSectionFooter(text: footer)
            }
        }
    }
}

// MARK: - Card row chrome

/// The base card-row chrome — surface1 default, surface3 on focus, the
/// 120pt minimum height, and the chromeFocus lift. Every concrete row
/// type below pours its content through this so focus visuals stay
/// identical across the whole Settings stack.
struct SettingsCardRow<Content: View>: View {
    @Environment(\.isFocused) private var isFocused
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                    .fill(isFocused ? Constants.Colors.surface3 : Constants.Colors.surface1)
            )
            .chromeFocus()
    }
}

// MARK: - Toggle row

/// Card row with a Toggle on the right. `subtitle` is optional helper
/// copy that sits under the title — use it for one-line context that
/// doesn't warrant a section footer.
struct SettingsToggleRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var isEnabled: Bool = true

    init(icon: String? = nil,
         title: String,
         subtitle: String? = nil,
         isOn: Binding<Bool>,
         isEnabled: Bool = true) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isEnabled = isEnabled
    }

    var body: some View {
        SettingsCardRow {
            HStack(spacing: 24) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(Constants.Colors.accent)
                        .frame(width: 64, height: 64)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(isEnabled ? .white : .white.opacity(0.4))

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(Constants.Colors.accent)
                    .disabled(!isEnabled)
            }
        }
    }
}

// MARK: - Picker nav row

/// Card row that pushes an option-picker screen. The right-hand side
/// shows the current value so the user can read state without entering
/// the picker.
struct SettingsPickerNavRow<Destination: View>: View {
    let icon: String?
    let title: String
    let value: String
    @ViewBuilder var destination: () -> Destination

    init(icon: String? = nil,
         title: String,
         value: String,
         @ViewBuilder destination: @escaping () -> Destination) {
        self.icon = icon
        self.title = title
        self.value = value
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            SettingsCardRow {
                HStack(spacing: 24) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 36))
                            .foregroundColor(Constants.Colors.accent)
                            .frame(width: 64, height: 64)
                    }

                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Spacer()

                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .buttonStyle(.cardChrome)
    }
}

// MARK: - Read-only value row

/// Non-interactive card row showing a label and a value — for things like
/// "Cache Size", "Version", "Build". Skips focus chrome since there's
/// nothing to do with it.
struct SettingsValueRow: View {
    let icon: String?
    let title: String
    let value: String

    init(icon: String? = nil, title: String, value: String) {
        self.icon = icon
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(spacing: 24) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(Constants.Colors.accent)
                    .frame(width: 64, height: 64)
            }

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }
}

// MARK: - Action row (button)

/// Tappable card row with an icon, title, optional subtitle, and an
/// optional `tint` (red for destructive, orange for "reset", default
/// accent for neutral). Used for things like "Clear Cache", "Reset All
/// Settings", "Change PIN".
struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let tint: Color
    let action: () -> Void

    init(icon: String,
         title: String,
         subtitle: String? = nil,
         tint: Color = Constants.Colors.accent,
         action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            SettingsCardRow {
                HStack(spacing: 24) {
                    Image(systemName: icon)
                        .font(.system(size: 36))
                        .foregroundColor(tint)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(tint)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }
            }
        }
        .buttonStyle(.cardChrome)
    }
}

// MARK: - Generic option picker screen

/// A single picker option. The `subtitle` slot lets us mirror the
/// `VStack { rawValue + description }` shape the old Form pickers used
/// for VideoQuality, AudioQuality, StreamingMode, SubtitleMode, etc.
struct SettingsPickerOption<Value: Hashable>: Identifiable {
    let id: AnyHashable
    let value: Value
    let title: String
    let subtitle: String?
    let leading: AnyView?

    init(value: Value,
         title: String,
         subtitle: String? = nil,
         leading: AnyView? = nil) {
        self.id = AnyHashable(value)
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
    }
}

/// Pushed picker screen that mirrors the Settings sub-page chrome.
/// One row per option, checkmark on the current selection, taps the
/// row to commit and pop. Generic over the bound value type so
/// String-backed and Int-backed pickers share one implementation.
struct SettingsOptionPickerView<Value: Hashable>: View {
    let title: String
    let footer: String?
    @Binding var selection: Value
    let options: [SettingsPickerOption<Value>]

    @Environment(\.dismiss) private var dismiss

    init(title: String,
         footer: String? = nil,
         selection: Binding<Value>,
         options: [SettingsPickerOption<Value>]) {
        self.title = title
        self.footer = footer
        self._selection = selection
        self.options = options
    }

    var body: some View {
        SettingsCardScreen(title: title) {
            VStack(spacing: 12) {
                ForEach(options) { option in
                    Button {
                        selection = option.value
                        dismiss()
                    } label: {
                        SettingsCardRow {
                            HStack(spacing: 24) {
                                if let leading = option.leading {
                                    leading
                                        .frame(width: 40, height: 40)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(option.title)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)

                                    if let subtitle = option.subtitle {
                                        Text(subtitle)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.55))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }

                                Spacer()

                                if option.value == selection {
                                    Image(systemName: "checkmark")
                                        .font(.title3)
                                        .foregroundColor(Constants.Colors.accent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.cardChrome)
                }
            }

            if let footer {
                SettingsSectionFooter(text: footer)
            }
        }
    }
}
