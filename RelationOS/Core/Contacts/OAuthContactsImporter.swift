import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Google People + Microsoft Graph contact import.
///
/// Uses `ASWebAuthenticationSession` with the OAuth 2.0 Authorization
/// Code flow + PKCE (no client secret on the device). The user must
/// register two app credentials and drop their identifiers into the
/// app's Info.plist:
///
/// ```
/// GoogleOAuthClientID   = <client id from Google Cloud > APIs & Services > Credentials>
///                         (iOS application type — Bundle ID com.relationos.app)
/// GoogleOAuthRedirectScheme = com.googleusercontent.apps.<reversed-client-id-suffix>
///                         (must also be added to CFBundleURLTypes)
///
/// MicrosoftOAuthClientID  = <Application (client) ID from Azure portal >
///                            App registrations > RelationOS>
/// MicrosoftOAuthRedirectURI = msauth.com.relationos.app://auth
///                            (must also be added to CFBundleURLTypes
///                             as scheme `msauth.com.relationos.app`)
/// ```
///
/// Until those keys are populated the menu buttons in
/// `ContactsListView` are hidden so we never ship a button that fails
/// silently. `isConfigured(for:)` is the single source of truth for
/// the visibility check.
///
/// Scopes requested are read-only:
///   Google:    https://www.googleapis.com/auth/contacts.readonly
///   Microsoft: Contacts.Read offline_access (offline_access is also
///              minimal — we don't currently refresh tokens, but Graph
///              requires it for any token longer than 1 hour).
///
/// Tokens are NOT persisted. Each import flow runs end-to-end inside
/// one user gesture and discards the token when done. This keeps us
/// out of "is RelationOS continuously reading your contacts?" privacy
/// territory for App Review.
@MainActor
final class OAuthContactsImporter: NSObject {
    enum Provider {
        case google
        case microsoft
    }

    enum OAuthError: Error {
        case notConfigured
        case userCancelled
        case authFailed(String)
        case tokenExchangeFailed(String)
        case fetchFailed(String)
    }

    static let shared = OAuthContactsImporter()
    private var anchor: ASPresentationAnchor?
    private var activeSession: ASWebAuthenticationSession?

    // MARK: - Public

    static func isConfigured(for provider: Provider) -> Bool {
        switch provider {
        case .google:
            let id = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String
            let sch = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthRedirectScheme") as? String
            return !(id?.isEmpty ?? true) && !(sch?.isEmpty ?? true)
        case .microsoft:
            let id = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as? String
            let uri = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthRedirectURI") as? String
            return !(id?.isEmpty ?? true) && !(uri?.isEmpty ?? true)
        }
    }

    /// Run the full flow: auth → token → fetch → map. Set `anchor` from
    /// the calling view so iOS knows where to attach the system browser
    /// sheet. Throws `OAuthError` on any failure.
    func importContacts(from provider: Provider, anchor: ASPresentationAnchor) async throws -> [Contact] {
        self.anchor = anchor
        guard Self.isConfigured(for: provider) else { throw OAuthError.notConfigured }
        switch provider {
        case .google:
            return try await runGoogle()
        case .microsoft:
            return try await runMicrosoft()
        }
    }

    // MARK: - Google

    private func runGoogle() async throws -> [Contact] {
        let clientId = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as! String
        let redirectScheme = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthRedirectScheme") as! String
        let redirectURI = "\(redirectScheme):/oauth/callback"
        let scope = "https://www.googleapis.com/auth/contacts.readonly"

        let pkce = PKCEPair.generate()
        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let code = try await runWebAuth(url: auth.url!, callbackScheme: redirectScheme)

        // Exchange code for access token (PKCE — no client secret).
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = formEncode([
            "client_id": clientId,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "")
        }

        // Page through People.connections.
        var rows: [Contact] = []
        var pageToken: String? = nil
        repeat {
            var url = URLComponents(string: "https://people.googleapis.com/v1/people/me/connections")!
            url.queryItems = [
                URLQueryItem(name: "personFields", value: "names,emailAddresses,phoneNumbers"),
                URLQueryItem(name: "pageSize", value: "200"),
            ]
            if let pt = pageToken {
                url.queryItems?.append(URLQueryItem(name: "pageToken", value: pt))
            }
            var pReq = URLRequest(url: url.url!)
            pReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (pData, _) = try await URLSession.shared.data(for: pReq)
            guard let pJson = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                throw OAuthError.fetchFailed(String(data: pData, encoding: .utf8) ?? "")
            }
            let conns = pJson["connections"] as? [[String: Any]] ?? []
            for p in conns {
                guard let c = mapGoogle(person: p) else { continue }
                rows.append(c)
            }
            pageToken = pJson["nextPageToken"] as? String
        } while pageToken != nil
        return rows
    }

    private func mapGoogle(person: [String: Any]) -> Contact? {
        let resourceName = person["resourceName"] as? String
        let names = (person["names"] as? [[String: Any]]) ?? []
        let primaryName = names.first?["displayName"] as? String
        let emails = (person["emailAddresses"] as? [[String: Any]]) ?? []
        let phones = (person["phoneNumbers"] as? [[String: Any]]) ?? []
        let email = emails.first?["value"] as? String
        let phone = phones.first?["value"] as? String

        let displayName: String
        if let n = primaryName, !n.isEmpty {
            displayName = n
        } else if let e = email, !e.isEmpty {
            displayName = e
        } else if let p = phone, !p.isEmpty {
            displayName = p
        } else {
            return nil
        }
        return Contact(
            name: displayName,
            phone: phone,
            email: email,
            source: .google,
            externalId: resourceName
        )
    }

    // MARK: - Microsoft

    private func runMicrosoft() async throws -> [Contact] {
        let clientId = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthClientID") as! String
        let redirectURI = Bundle.main.object(forInfoDictionaryKey: "MicrosoftOAuthRedirectURI") as! String
        // Scheme = everything before "://"
        let redirectScheme: String = {
            let p = redirectURI.components(separatedBy: "://")
            return p.first ?? "msauth"
        }()
        let scope = "Contacts.Read offline_access"

        let pkce = PKCEPair.generate()
        var auth = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!
        auth.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        let code = try await runWebAuth(url: auth.url!, callbackScheme: redirectScheme)

        var req = URLRequest(url: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = formEncode([
            "client_id": clientId,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
            "scope": scope,
        ])
        req.httpBody = body.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "")
        }

        // Page through /me/contacts.
        var rows: [Contact] = []
        var next: String? = "https://graph.microsoft.com/v1.0/me/contacts?$top=200"
        while let url = next.flatMap(URL.init(string:)) {
            var pReq = URLRequest(url: url)
            pReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (pData, _) = try await URLSession.shared.data(for: pReq)
            guard let pJson = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] else {
                throw OAuthError.fetchFailed(String(data: pData, encoding: .utf8) ?? "")
            }
            let values = pJson["value"] as? [[String: Any]] ?? []
            for v in values {
                guard let c = mapMicrosoft(contact: v) else { continue }
                rows.append(c)
            }
            next = pJson["@odata.nextLink"] as? String
        }
        return rows
    }

    private func mapMicrosoft(contact: [String: Any]) -> Contact? {
        let id = contact["id"] as? String
        let display = contact["displayName"] as? String
        let emails = contact["emailAddresses"] as? [[String: Any]]
        let email = (emails?.first?["address"] as? String)
        let mobile = contact["mobilePhone"] as? String
        let business = (contact["businessPhones"] as? [String])?.first
        let phone = mobile ?? business

        let name: String
        if let d = display, !d.isEmpty {
            name = d
        } else if let e = email, !e.isEmpty {
            name = e
        } else if let p = phone, !p.isEmpty {
            name = p
        } else {
            return nil
        }
        return Contact(
            name: name,
            phone: phone,
            email: email,
            source: .microsoft,
            externalId: id
        )
    }

    // MARK: - Shared helpers

    private func runWebAuth(url: URL, callbackScheme: String) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: OAuthError.userCancelled); return
                }
                if let error = error {
                    cont.resume(throwing: OAuthError.authFailed(error.localizedDescription)); return
                }
                guard let url = callback,
                      let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
                    cont.resume(throwing: OAuthError.authFailed("missing code in callback")); return
                }
                cont.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.activeSession = session
            if !session.start() {
                cont.resume(throwing: OAuthError.authFailed("session.start() returned false"))
            }
        }
    }

    private func formEncode(_ params: [String: String]) -> String {
        params.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
    }
}

extension OAuthContactsImporter: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Anchor is captured on the main actor; this nonisolated read is
        // safe because UIWindow is sendable for read access and is only
        // touched on the main thread by ASWebAuthenticationSession.
        MainActor.assumeIsolated {
            return self.anchor ?? ASPresentationAnchor()
        }
    }
}

// MARK: - PKCE

private struct PKCEPair {
    let verifier: String
    let challenge: String

    static func generate() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).base64URLEncodedString()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
        return PKCEPair(verifier: verifier, challenge: challenge)
    }
}

private extension Data {
    /// RFC 7636 §4.2 — base64url, no padding.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
