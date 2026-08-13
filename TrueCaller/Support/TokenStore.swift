import Foundation

/// Token persistence that prefers the Keychain but falls back to UserDefaults.
///
/// Keychain is the secure primary. Sideloaded builds (e.g. AltStore with a free
/// Apple ID) sometimes lack the `keychain-access-groups` entitlement and get
/// `errSecMissingEntitlement` on every write; in that case we persist to
/// UserDefaults so the token still works, and flag the fallback for the UI.
enum TokenStore {
    enum Storage {
        case keychain
        case userDefaults(error: KeychainError?, status: OSStatus?)
    }

    private static let fallbackKey = "truecaller.installationId"
    private static let usesKeychainKey = "truecaller.token.isKeychain"

    static func save(_ value: String) -> Storage {
        do {
            try KeychainStore.save(value)
            // Fresh keychain write; clear any prior fallback.
            UserDefaults.standard.removeObject(forKey: fallbackKey)
            UserDefaults.standard.set(true, forKey: usesKeychainKey)
            return .keychain
        } catch {
            let keychainError = error as? KeychainError
            UserDefaults.standard.set(value, forKey: fallbackKey)
            UserDefaults.standard.set(false, forKey: usesKeychainKey)
            return .userDefaults(error: keychainError, status: keychainError?.status)
        }
    }

    static func load() -> String? {
        if let value = KeychainStore.load() {
            return value
        }
        return UserDefaults.standard.string(forKey: fallbackKey)
    }

    static func delete() {
        KeychainStore.delete()
        UserDefaults.standard.removeObject(forKey: fallbackKey)
    }

    /// True when the token currently lives in UserDefaults rather than Keychain.
    static var isUsingFallback: Bool {
        UserDefaults.standard.bool(forKey: usesKeychainKey) == false
            && UserDefaults.standard.string(forKey: fallbackKey) != nil
    }
}
