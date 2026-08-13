import SwiftUI

/// App-wide settings backed by UserDefaults (country) and TokenStore (token).
@MainActor
final class SettingsStore: ObservableObject {
    @Published var token: String {
        didSet { _ = oldValue; tokenIsSaved = false }
    }
    @Published var tokenIsSaved: Bool
    @Published var isFallbackStorage: Bool
    @Published var errorMessage: String?
    @Published var country: Country

    private let countryKey = "defaultCountry"

    init() {
        let stored = UserDefaults.standard.string(forKey: "defaultCountry")
        country = Country.all.first { $0.id == stored } ?? .default
        let loaded = TokenStore.load()
        token = loaded ?? ""
        tokenIsSaved = loaded != nil
        isFallbackStorage = TokenStore.isUsingFallback
    }

    func saveToken() {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        errorMessage = nil
        let result = TokenStore.save(value)
        if case .keychain = result {
            tokenIsSaved = true
            isFallbackStorage = false
        }
        if case .userDefaults(let keychainError, let status) = result {
            tokenIsSaved = true
            isFallbackStorage = true
            // Fallback still saved the token, so this is informational, not fatal.
            let detail = keychainError?.errorDescription ?? (status.map { "Keychain error \($0)" } ?? "unknown")
            self.errorMessage = "Keychain save failed (\(detail)); token stored with reduced security (regular storage). It will still work."
        }
    }

    func clearToken() {
        TokenStore.delete()
        token = ""
        tokenIsSaved = false
        isFallbackStorage = false
        errorMessage = nil
    }

    func selectCountry(_ c: Country) {
        country = c
        UserDefaults.standard.set(c.id, forKey: countryKey)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var showToken = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if tokenSet {
                        Label("Token is set", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Token is not set", systemImage: "lock.open")
                            .foregroundStyle(.secondary)
                    }

                    if tokenSet {
                        if settings.isFallbackStorage {
                            Label("Stored in app storage — Keychain unavailable", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } else {
                            Label("Stored in Keychain", systemImage: "checkmark.shield.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }

                    HStack {
                        if showToken {
                            TextField("Truecaller installationId", text: $settings.token)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Truecaller installationId", text: $settings.token)
                        }
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                    }

                    HStack {
                        Button("Save Token") { settings.saveToken() }
                            .disabled(!tokenSet)
                        Spacer()
                        Button("Clear", role: .destructive) { settings.clearToken() }
                    }
                } header: {
                    Text("Truecaller Token")
                } footer: {
                    Text("The token is your Truecaller installationId. It is stored on this device (in the iOS Keychain when available, otherwise regular app storage) and is sent as the `Authorization: Bearer` header to search5-noneu.truecaller.com.")
                }

                if let message = settings.errorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("Default country", selection: countryBinding) {
                        ForEach(Country.all) { c in
                            Text("\(c.flag) \(c.name) (\(c.dialingCode))")
                                .tag(c)
                        }
                    }
                } header: {
                    Text("Lookup Defaults")
                } footer: {
                    Text("Numbers pasted without a +country prefix are treated as national numbers in this country.")
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var countryBinding: Binding<Country> {
        Binding(
            get: { settings.country },
            set: { settings.selectCountry($0) }
        )
    }

    private var tokenSet: Bool {
        !settings.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct AboutView: View {
    var body: some View {
        Form {
            Section {
                Text("""
                An unofficial Truecaller lookup client. It calls the same public endpoint as a personal `tc.py` script:

                GET /v2/search?q=<number>&countryCode=<cc>&type=4&encoding=json

                Use it responsibly: the unofficial API is rate-limited, and hammering it can extend a temporary throttle.
                """)
            }
        }
        .navigationTitle("About")
    }
}
