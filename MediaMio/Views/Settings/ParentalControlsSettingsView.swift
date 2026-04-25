//
//  ParentalControlsSettingsView.swift
//  MediaMio
//
//  The parental-controls settings screen. Three phases:
//    1) No PIN set:     show a one-time PIN setup form.
//    2) PIN set but locked:  ask for the PIN before showing anything.
//    3) Unlocked:       show the toggle, max-rating picker, and PIN actions.
//
//  Unlock is session-scoped (resets when the view leaves the hierarchy) so a
//  child can't wander into Settings after mom walked away and the screen
//  stayed on the unlocked state.
//
//  Card-style layout matching `AccountSettingsView` — every phase pours
//  through `SettingsCardScreen` so the heading and chrome stay consistent
//  even though the content changes.
//

import SwiftUI

struct ParentalControlsSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    @State private var isUnlocked: Bool = false
    @State private var hasPIN: Bool = KeychainHelper.shared.hasParentalPIN()

    var body: some View {
        Group {
            if !hasPIN {
                ParentalControlsSetupView(
                    settingsManager: settingsManager,
                    onComplete: {
                        hasPIN = true
                        isUnlocked = true
                    }
                )
            } else if !isUnlocked {
                ParentalControlsUnlockView(
                    onUnlock: { isUnlocked = true },
                    onForgot: {
                        // Recovery flow: clearing the PIN *also* turns off
                        // parental controls. This is intentional — if a user
                        // forgets the PIN, we'd rather drop them out of
                        // protected state than strand them.
                        KeychainHelper.shared.clearParentalPIN()
                        settingsManager.parentalControlsEnabled = false
                        hasPIN = false
                    }
                )
            } else {
                ParentalControlsMainView(
                    settingsManager: settingsManager,
                    onClearPIN: {
                        KeychainHelper.shared.clearParentalPIN()
                        settingsManager.parentalControlsEnabled = false
                        hasPIN = false
                        isUnlocked = false
                    }
                )
            }
        }
        .onDisappear {
            // Re-lock on leave so the next visit requires the PIN again.
            isUnlocked = false
        }
    }
}

// MARK: - Setup phase

private struct ParentalControlsSetupView: View {
    @ObservedObject var settingsManager: SettingsManager
    let onComplete: () -> Void

    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case pin, confirm, save
    }

    private var canSave: Bool {
        pin.count >= 4 && pin.count <= 6 && pin.allSatisfy(\.isNumber) && confirmPin == pin
    }

    var body: some View {
        SettingsCardScreen(title: "Parental Controls") {
            heroCard

            SettingsSection("Choose a PIN", footer: "Don't lose it — the only recovery path turns parental controls off.") {
                SettingsSecureFieldRow(
                    title: "PIN",
                    text: $pin,
                    isFocused: focused == .pin,
                    onFocus: { focused = .pin }
                )

                SettingsSecureFieldRow(
                    title: "Confirm PIN",
                    text: $confirmPin,
                    isFocused: focused == .confirm,
                    onFocus: { focused = .confirm }
                )

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }

            SettingsSection {
                SettingsActionRow(
                    icon: "lock.shield.fill",
                    title: "Save PIN and Enable",
                    tint: canSave ? Constants.Colors.accent : .white.opacity(0.3)
                ) {
                    savePIN()
                }
                .disabled(!canSave)
            }
        }
        .onAppear { focused = .pin }
    }

    private var heroCard: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.accent.opacity(0.45))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Set a 4-digit PIN")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundColor(.white)

                Text("Required to change parental controls in the future.")
                    .font(.system(size: 23))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }

    private func savePIN() {
        guard canSave else { return }
        do {
            try KeychainHelper.shared.saveParentalPIN(pin)
            settingsManager.parentalControlsEnabled = true
            onComplete()
        } catch {
            errorMessage = "Could not save PIN. Please try again."
        }
    }
}

// MARK: - Unlock phase

private struct ParentalControlsUnlockView: View {
    let onUnlock: () -> Void
    let onForgot: () -> Void

    @State private var pin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case pin, submit, forgot
    }

    var body: some View {
        SettingsCardScreen(title: "Parental Controls") {
            heroCard

            SettingsSection("Enter PIN") {
                SettingsSecureFieldRow(
                    title: "PIN",
                    text: $pin,
                    isFocused: focused == .pin,
                    onFocus: { focused = .pin }
                )

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
                }
            }

            SettingsSection {
                SettingsActionRow(
                    icon: "lock.open.fill",
                    title: "Unlock",
                    tint: pin.isEmpty ? .white.opacity(0.3) : Constants.Colors.accent
                ) {
                    attemptUnlock()
                }
                .disabled(pin.isEmpty)

                SettingsActionRow(
                    icon: "questionmark.circle.fill",
                    title: "Forgot PIN",
                    subtitle: "Turns off parental controls",
                    tint: .red
                ) {
                    onForgot()
                }
            }
        }
        .onAppear { focused = .pin }
    }

    private var heroCard: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.accent.opacity(0.45))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Locked")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundColor(.white)

                Text("Enter your PIN to change parental controls.")
                    .font(.system(size: 23))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(Constants.Colors.surface1)
        )
    }

    private func attemptUnlock() {
        guard let stored = KeychainHelper.shared.parentalPIN() else {
            // If the PIN somehow vanished from Keychain (device restore, etc.)
            // fall through to the forgot-PIN flow rather than dead-ending.
            onForgot()
            return
        }
        if pin == stored {
            onUnlock()
        } else {
            errorMessage = "Incorrect PIN. Try again."
            pin = ""
        }
    }
}

// MARK: - Main (unlocked) phase

private struct ParentalControlsMainView: View {
    @ObservedObject var settingsManager: SettingsManager
    let onClearPIN: () -> Void

    @State private var showChangePIN: Bool = false

    private var selectedLevel: ContentRatingLevel {
        ContentRatingLevel(rawValue: settingsManager.parentalControlsMaxRating) ?? .teen
    }

    var body: some View {
        SettingsCardScreen(title: "Parental Controls") {
            SettingsSection(footer: settingsManager.parentalControlsEnabled
                            ? "Content above the selected rating is hidden from Home, Library, and Search."
                            : "Turn on to filter mature content out of the app.") {
                SettingsToggleRow(
                    icon: "lock.shield.fill",
                    title: "Enable Parental Controls",
                    isOn: $settingsManager.parentalControlsEnabled
                )
            }

            SettingsSection(
                "Content Level",
                footer: "Currently allowing: \(selectedLevel.description). Items without a known rating are also hidden while controls are on."
            ) {
                SettingsPickerNavRow(
                    icon: "rosette",
                    title: "Maximum Rating",
                    value: selectedLevel.rawValue
                ) {
                    SettingsOptionPickerView(
                        title: "Maximum Rating",
                        selection: $settingsManager.parentalControlsMaxRating,
                        options: ContentRatingLevel.allCases.map {
                            SettingsPickerOption(
                                value: $0.rawValue,
                                title: $0.rawValue,
                                subtitle: $0.description
                            )
                        }
                    )
                }
            }

            SettingsSection("PIN") {
                SettingsActionRow(
                    icon: "key.fill",
                    title: "Change PIN"
                ) {
                    showChangePIN = true
                }

                SettingsActionRow(
                    icon: "xmark.shield.fill",
                    title: "Remove PIN & Disable",
                    tint: .red
                ) {
                    onClearPIN()
                }
            }

            SettingsSection {
                InfoNoteRow(
                    text: "Filtering happens both on the server (via MaxOfficialRating) and in the app. Accuracy depends on the server admin's rating-score configuration in Jellyfin."
                )
            }
        }
        .sheet(isPresented: $showChangePIN) {
            ChangePINSheet(onDone: { showChangePIN = false })
        }
    }
}

// MARK: - Change PIN sheet

private struct ChangePINSheet: View {
    let onDone: () -> Void

    @State private var oldPin: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case old, new, confirm
    }

    private var canSave: Bool {
        newPin.count >= 4 && newPin.count <= 6 && newPin.allSatisfy(\.isNumber) && confirmPin == newPin && !oldPin.isEmpty
    }

    var body: some View {
        NavigationStack {
            SettingsCardScreen(title: "Change PIN") {
                SettingsSection("Verify Current PIN") {
                    SettingsSecureFieldRow(
                        title: "Current PIN",
                        text: $oldPin,
                        isFocused: focused == .old,
                        onFocus: { focused = .old }
                    )
                }

                SettingsSection("Choose New PIN") {
                    SettingsSecureFieldRow(
                        title: "New PIN",
                        text: $newPin,
                        isFocused: focused == .new,
                        onFocus: { focused = .new }
                    )

                    SettingsSecureFieldRow(
                        title: "Confirm New PIN",
                        text: $confirmPin,
                        isFocused: focused == .confirm,
                        onFocus: { focused = .confirm }
                    )

                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.leading, 4)
                    }
                }

                SettingsSection {
                    SettingsActionRow(
                        icon: "checkmark.shield.fill",
                        title: "Save New PIN",
                        tint: canSave ? Constants.Colors.accent : .white.opacity(0.3)
                    ) {
                        save()
                    }
                    .disabled(!canSave)

                    SettingsActionRow(
                        icon: "xmark",
                        title: "Cancel",
                        tint: .white.opacity(0.7)
                    ) {
                        onDone()
                    }
                }
            }
        }
    }

    private func save() {
        guard KeychainHelper.shared.parentalPIN() == oldPin else {
            errorMessage = "Current PIN is incorrect."
            return
        }
        do {
            try KeychainHelper.shared.saveParentalPIN(newPin)
            onDone()
        } catch {
            errorMessage = "Could not save new PIN."
        }
    }
}

// MARK: - Secure field row

/// Card-row-shaped SecureField. tvOS routes secure entry through a system
/// overlay regardless of the host view's chrome, so we just need the
/// outer card visuals to match the rest of the Settings stack.
private struct SettingsSecureFieldRow: View {
    let title: String
    @Binding var text: String
    let isFocused: Bool
    let onFocus: () -> Void

    var body: some View {
        SettingsCardRow {
            HStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Constants.Colors.accent)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.55))

                    SecureField("", text: $text)
                        .font(.title3)
                        .foregroundColor(.white)
                        .onTapGesture(perform: onFocus)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ParentalControlsSettingsView(settingsManager: SettingsManager())
    }
}
