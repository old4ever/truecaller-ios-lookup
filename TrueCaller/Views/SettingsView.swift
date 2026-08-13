import SwiftUI

/// App-wide settings backed by UserDefaults (country) and Keychain (token).
@MainActor
final class SettingsStore: ObservableObject {
    @Published var token: String {
        didSet { _ = oldValue; tokenIsSaved = false }
    }
    @Published var tokenIsSaved: Bool
    @Published var country: Country

    private let countryKey = "defaultCountry"

    init() {
        let stored = UserDefaults.standard.string(forKey: "defaultCountry")
        country = Country.all.first { $0.id == stored } ?? .default
        token = KeychainStore.load() ?? ""
        tokenIsSaved = KeychainStore.load() != nil
    }

    func saveToken() {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try KeychainStore.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
            tokenIsSaved = true
        } catch {
            // Surface through the view's error state.
            self.errorMessage = error.localizedDescription
        }
    }

    func clearToken() {
        KeychainStore.delete()
        token = ""
        tokenIsSaved = false
    }

    func selectCountry(_ c: Country) {
        country = c
        UserDefaults.standard.set(c.id, forKey: countryKey)
    }

    var errorMessage: String?
}

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var showToken = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
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

                    if settings.tokenIsSaved && !settings.token.isEmpty {
                        Label("Token saved to Keychain", systemImage: "checkmark.shield.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Button("Save Token") { settings.saveToken() }
                            .disabled(settings.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        Button("Clear", role: .destructive) { settings.clearToken() }
                    }
                } header: {
                    Text("Truecaller Token")
                } footer: {
                    Text("The token is your Truecaller installationId. It is stored only on this device, in the iOS Keychain, and is sent as the `Authorization: Bearer` header to search5-noneu.truecaller.com.")
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
