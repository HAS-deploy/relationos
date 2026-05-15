import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Microsoft Graph OAuth for Mail.Read, with persistent tokens.
///
/// Differs from `OAuthContactsImporter` in two ways:
///   1. Scope is `Mail.Read offline_access` — `offline_access` gets us a
///      refresh token, which the contacts importer never needed.
///   2. Tokens persist (keychain) so background email syncs and Foundation
///      Models summarization on launch don't require the user to re-OAuth.
///
/// Configure with `MicrosoftOAuthClientID` + `MicrosoftOAuthRedirectURI`
/// from Info.plist (same keys the contacts importer reads — one Azure app
/// registration, two scopes).
@MainActor
final class MicrosoftMailAuth: NSObject {
    enum Provider {
        static let scope = "Mail.Read offline_access"
        static let authURL = "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
        static let tokenURL = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    }

    enum AuthError: Error {
        case notConfigured
        case userCancelled
        case authFailed(String)
        case tokenExchangeFailed(String)
        case refreshFailed(String)
    }

    static let shared = MicrosoftMailAuth()
    private var anchor: ASPresentationAnchor?
    private var activeSession: ASWebAuthenticationSession?

    static var isConfigured: Bool {
        let id = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as? String
        let uri = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthRedirectURI") as? String
        return !(id?.isEmpty ?? true) && !(uri?.isEmpty ?? true)
    }

    static var isConnected: Bool { MailKeychain.hasAnyToken }

    // MARK: - First-time connect

    func connect(anchor: ASPresentationAnchor) async throws {
        self.anchor = anchor
        guard Self.isConfigured else { throw AuthError.notConfigured }
        let clientId = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as! String
        let redirectURI = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthRedirectURI") as! String
        let redirectScheme = redirectURI.components(separatedBy: "://").first ?? "msauth"

        let pkce = PKCE.generate()
        var auth = URLComponents(string: Provider.authURL)!
        auth.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Provider.scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        let code = try await runWebAuth(url: auth.url!, callbackScheme: redirectScheme)
        try await exchangeCode(code, verifier: pkce.verifier, clientId: clientId, redirectURI: redirectURI)
    }

    private func exchangeCode(_ code: String, verifier: String,
                              clientId: String, redirectURI: String) async throws {
        var req = URLRequest(url: URL(string: Provider.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = OAuthForm.encode([
            "client_id": clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "scope": Provider.scope,
        ]).data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Double else {
            throw AuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "")
        }
        let refresh = json["refresh_token"] as? String
        MailKeychain.saveTokens(access: access, refresh: refresh, expiresIn: expiresIn)
    }

    // MARK: - Token refresh

    /// Refreshes the access token if it's stale, returns a fresh one.
    /// Throws if no refresh token is available (user must re-connect).
    func currentAccessToken() async throws -> String {
        if !MailKeychain.accessTokenIsStale(), let token = MailKeychain.accessToken() {
            return token
        }
        guard let refresh = MailKeychain.refreshToken(),
              let clientId = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as? String,
              !clientId.isEmpty else {
            throw AuthError.refreshFailed("no refresh token; user must reconnect")
        }
        var req = URLRequest(url: URL(string: Provider.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = OAuthForm.encode([
            "client_id": clientId,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
            "scope": Provider.scope,
        ]).data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Double else {
            throw AuthError.refreshFailed(String(data: data, encoding: .utf8) ?? "")
        }
        let newRefresh = (json["refresh_token"] as? String) ?? refresh
        MailKeychain.saveTokens(access: access, refresh: newRefresh, expiresIn: expiresIn)
        return access
    }

    // MARK: - Disconnect

    func disconnect() {
        MailKeychain.removeAll()
    }

    // MARK: - Shared helpers

    private func runWebAuth(url: URL, callbackScheme: String) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: AuthError.userCancelled); return
                }
                if let error = error {
                    cont.resume(throwing: AuthError.authFailed(error.localizedDescription)); return
                }
                guard let url = callback,
                      let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
                    cont.resume(throwing: AuthError.authFailed("missing code in callback")); return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false  // keep MS session warm
            self.activeSession = session
            if !session.start() {
                cont.resume(throwing: AuthError.authFailed("session.start() returned false"))
            }
        }
    }
}

extension MicrosoftMailAuth: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { self.anchor ?? ASPresentationAnchor() }
    }
}

// MARK: - Helpers (PKCE + form encode)

enum OAuthForm {
    static func encode(_ params: [String: String]) -> String {
        params.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
    }
}

struct PKCE {
    let verifier: String
    let challenge: String
    static func generate() -> PKCE {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let v = Data(bytes).base64URLEncodedString()
        let c = Data(SHA256.hash(data: Data(v.utf8))).base64URLEncodedString()
        return PKCE(verifier: v, challenge: c)
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
