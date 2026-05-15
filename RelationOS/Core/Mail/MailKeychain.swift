import Foundation
import Security

/// Tiny keychain wrapper for the Microsoft Graph OAuth refresh token.
///
/// Stores three items under the `com.relationos.app.mail.microsoft.*`
/// service prefix:
///   - `access_token` (kSecAttrService = "...access_token") — short-lived (~1h).
///   - `refresh_token` (...refresh_token) — long-lived (~90 days).
///   - `access_token_expires_at` (...expires_at) — TimeInterval as a String.
///
/// We persist both tokens because Foundation Models calls + email fetches
/// happen on background app launches (widget timeline refresh, periodic
/// summarization). Keychain values are protected with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so they're available
/// background but never sync to iCloud or another device. Wipe via
/// `removeAll()` from Settings → "Disconnect Outlook".
enum MailKeychain {
    private static let servicePrefix = "com.relationos.app.mail.microsoft"
    private enum Key: String { case access = "access_token"
                                  case refresh = "refresh_token"
                                  case expiresAt = "expires_at" }

    static func saveTokens(access: String, refresh: String?, expiresIn: TimeInterval) {
        write(.access, value: access)
        if let refresh = refresh { write(.refresh, value: refresh) }
        let expiresAt = Date().addingTimeInterval(expiresIn).timeIntervalSince1970
        write(.expiresAt, value: String(expiresAt))
    }

    static func accessToken() -> String? { read(.access) }
    static func refreshToken() -> String? { read(.refresh) }

    /// Token is "stale" if it expires within the next 60 seconds — we
    /// proactively refresh before the network call sees a 401.
    static func accessTokenIsStale() -> Bool {
        guard let raw = read(.expiresAt), let expires = TimeInterval(raw) else { return true }
        return expires < Date().timeIntervalSince1970 + 60
    }

    static var hasAnyToken: Bool { accessToken() != nil || refreshToken() != nil }

    static func removeAll() {
        for key in [Key.access, .refresh, .expiresAt] { delete(key) }
    }

    // MARK: - Internal

    private static func service(for key: Key) -> String { "\(servicePrefix).\(key.rawValue)" }

    private static func write(_ key: Key, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: key),
        ]
        SecItemDelete(query as CFDictionary)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: key),
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private static func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: key),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: key),
        ]
        SecItemDelete(query as CFDictionary)
    }
}
