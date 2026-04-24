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

import SwiftUI

struct ParentalControlsSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager

    @State private var isUnlocked: Bool = false
    @State private var hasPIN: Bool = KeychainHelper.shared.hasParentalPIN()

    var body: some View {
        ZStack {
            Constants.Colors.background.ignoresSafeArea()

            if !hasPIN {
                PINSetupView(
                    settingsManager: settingsManager,
                    onComplete: {
                        hasPIN = true
                        isUnlocked = true
                    }
                )
            } else if !isUnlocked {
                PINUnlockView(
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
        .navigationTitle("Parental Controls")
        .onDisappear {
            // Re-lock on leave so the next visit requires the PIN again.
            isUnlocked = false
        }
    }
}

// MARK: - PIN Setup

private struct PINSetupView: View {
    @ObservedObject var settingsManager: SettingsManager
    let onComplete: () -> Void

    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case pin, confirm, save
    }

    var body: some View {
        Form {
            Section {
                Text("Set a 4-digit PIN")
                    .font(.title2)
                    .foregroundColor(.white)
                    .listRowBackground(Constants.Colors.surface1)
            } footer: {
                Text("You'll enter this PIN to change parental controls. Don't lose it — the only recovery path turns parental controls off.")
                    .foregroundColor(.secondary)
            }

            Section {
                SecureField("PIN", text: $pin)
                    .foregroundColor(.white)
                    .focused($focused, equals: .pin)
                    .listRowBackground(Constants.Colors.surface1)

                SecureField("Confirm PIN", text: $confirmPin)
                    .foregroundColor(.white)
                    .focused($focused, equals: .confirm)
                    .listRowBackground(Constants.Colors.surface1)
            } footer: {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: savePIN) {
                    Text("Save PIN and Enable")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .focused($focused, equals: .save)
                .listRowBackground(Constants.Colors.accent)
                .disabled(!canSave)
            }
        }
        .buttonStyle(.plain)
        .onAppear { focused = .pin }
    }

    private var canSave: Bool {
        pin.count >= 4 && pin.count <= 6 && pin.allSatisfy(\.isNumber) && confirmPin == pin
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

// MARK: - PIN Unlock

private struct PINUnlockView: View {
    let onUnlock: () -> Void
    let onForgot: () -> Void

    @State private var pin: String = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field: Hashable {
        case pin, submit, forgot
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Constants.Colors.accent)
                    Text("Enter PIN")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .listRowBackground(Constants.Colors.surface1)
            } footer: {
                Text("Parental controls are locked. Enter your PIN to change settings.")
                    .foregroundColor(.secondary)
            }

            Section {
                SecureField("PIN", text: $pin)
                    .foregroundColor(.white)
                    .focused($focused, equals: .pin)
                    .listRowBackground(Constants.Colors.surface1)
            } footer: {
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button(action: attemptUnlock) {
                    Text("Unlock")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .focused($focused, equals: .submit)
                .listRowBackground(Constants.Colors.accent)
                .disabled(pin.isEmpty)
            }

            Section {
                Button(action: onForgot) {
                    Text("Forgot PIN (turns off parental controls)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                }
                .focused($focused, equals: .forgot)
                .listRowBackground(Constants.Colors.surface1)
            }
        }
        .buttonStyle(.plain)
        .onAppear { focused = .pin }
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

// MARK: - Main (Unlocked) View

private struct ParentalControlsMainView: View {
    @ObservedObject var settingsManager: SettingsManager
    let onClearPIN: () -> Void

    @State private var showChangePIN: Bool = false

    private var selectedLevel: ContentRatingLevel {
        ContentRatingLevel(rawValue: settingsManager.parentalControlsMaxRating) ?? .teen
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Parental Controls", isOn: $settingsManager.parentalControlsEnabled)
                    .foregroundColor(.white)
                    .tint(Constants.Colors.accent)
                    .listRowBackground(Constants.Colors.surface1)
            } footer: {
                Text(settingsManager.parentalControlsEnabled
                     ? "Content above the selected rating will be hidden from Home, Library, and Search."
                     : "Turn on to filter mature content from the app.")
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("Maximum Rating", selection: $settingsManager.parentalControlsMaxRating) {
                    ForEach(ContentRatingLevel.allCases) { level in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.rawValue)
                                .foregroundColor(.white)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(level.rawValue)
                        .listRowBackground(Constants.Colors.surface1)
                    }
                }
                .pickerStyle(.navigationLink)
                .foregroundColor(.white)
                .accentColor(Constants.Colors.accent)
                .listRowBackground(Constants.Colors.surface1)
                .disabled(!settingsManager.parentalControlsEnabled)
            } header: {
                Text("Content Level")
                    .foregroundColor(.white)
            } footer: {
                Text("Currently allowing: \(selectedLevel.description). Items without a known rating are also hidden while controls are on.")
                    .foregroundColor(.secondary)
            }

            Section {
                Button(action: { showChangePIN = true }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(Constants.Colors.accent)
                        Text("Change PIN")
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
                .listRowBackground(Constants.Colors.surface1)

                Button(role: .destructive, action: onClearPIN) {
                    HStack {
                        Image(systemName: "xmark.shield.fill")
                            .foregroundColor(.red)
                        Text("Remove PIN & Disable")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                .listRowBackground(Constants.Colors.surface1)
            } header: {
                Text("PIN")
                    .foregroundColor(.white)
            }

            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Filtering happens both on the server (via MaxOfficialRating) and in the app. Accuracy depends on the server admin's rating-score configuration in Jellyfin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showChangePIN) {
            ChangePINSheet(onDone: { showChangePIN = false })
        }
    }
}

// MARK: - Change PIN

private struct ChangePINSheet: View {
    let onDone: () -> Void

    @State private var oldPin: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()
                Form {
                    Section {
                        SecureField("Current PIN", text: $oldPin)
                            .foregroundColor(.white)
                            .listRowBackground(Constants.Colors.surface1)
                        SecureField("New PIN", text: $newPin)
                            .foregroundColor(.white)
                            .listRowBackground(Constants.Colors.surface1)
                        SecureField("Confirm New PIN", text: $confirmPin)
                            .foregroundColor(.white)
                            .listRowBackground(Constants.Colors.surface1)
                    } footer: {
                        if let error = errorMessage {
                            Text(error).foregroundColor(.red)
                        }
                    }

                    Section {
                        Button(action: save) {
                            Text("Save New PIN")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(Constants.Colors.accent)
                        .disabled(!canSave)

                        Button(action: onDone) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Constants.Colors.surface1)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Change PIN")
        }
    }

    private var canSave: Bool {
        newPin.count >= 4 && newPin.count <= 6 && newPin.allSatisfy(\.isNumber) && confirmPin == newPin && !oldPin.isEmpty
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

#Preview {
    NavigationStack {
        ParentalControlsSettingsView(settingsManager: SettingsManager())
    }
}
