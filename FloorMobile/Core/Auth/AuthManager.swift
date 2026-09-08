//
//  AuthManager.swift
//  FloorMobile
//

import Foundation
import os

/// Sole owner of the OIDC flow and of the tokens' lifecycle.
///
/// Being an actor, every token state transition is serialized: there is a
/// single refresh in flight at any time and concurrent callers await the
/// same result. This is the structural fix for the historical bug of four
/// concurrent refresh paths in the previous app.
final actor AuthManager {
    private let configuration: AuthConfiguration
    private let store: any TokenStore
    private let webAuthenticator: any WebAuthenticating
    private let urlSession: URLSession
    private let now: @Sendable () -> Date

    private var discovered: OIDCConfiguration?
    private var tokens: TokenSet?
    private var refreshTask: Task<TokenSet, Error>?

    init(
        configuration: AuthConfiguration = .dev,
        store: any TokenStore,
        webAuthenticator: any WebAuthenticating,
        urlSession: URLSession = .shared,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.store = store
        self.webAuthenticator = webAuthenticator
        self.urlSession = urlSession
        self.now = now
    }

    // MARK: - Public API

    /// Restores a persisted session at launch; returns its claims when found.
    func restoreSession() async -> IDTokenClaims? {
        guard let stored = await store.load() else { return nil }
        tokens = stored
        return try? IDTokenClaims(idToken: stored.idToken)
    }

    /// Runs the full Authorization Code + PKCE flow.
    func signIn() async throws -> IDTokenClaims {
        let oidc = try await discover()
        let pkce = PKCE()
        let state = Self.randomToken()
        let nonce = Self.randomToken()

        let authorizationURL = try Self.url(oidc.authorizationEndpoint, queryItems: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ])

        let callback = try await webAuthenticator.authenticate(
            url: authorizationURL,
            callbackScheme: configuration.redirectURI.scheme ?? "floormobile"
        )
        let code = try Self.authorizationCode(from: callback, expectedState: state)

        let newTokens = try await requestTokens(endpoint: oidc.tokenEndpoint, body: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": configuration.redirectURI.absoluteString,
            "client_id": configuration.clientID,
            "code_verifier": pkce.verifier,
        ])

        let claims = try IDTokenClaims(idToken: newTokens.idToken)
        try claims.validateNonce(nonce)

        try await store.save(newTokens)
        tokens = newTokens
        AppLog.auth.info("Sign-in succeeded")
        return claims
    }

    /// Returns a valid access token, refreshing it first when needed.
    func validToken() async throws -> String {
        if tokens == nil {
            tokens = await store.load()
        }
        if let tokens, tokens.isValid(now: now()) {
            return tokens.accessToken
        }
        return try await refreshedTokens().accessToken
    }

    /// Forces a refresh and returns the new access token. Used by `APIClient`
    /// after a 401: the server rejected a token the client believed valid.
    func refreshedAccessToken() async throws -> String {
        try await refreshedTokens().accessToken
    }

    /// Best-effort server-side logout; the local wipe happens regardless.
    func signOut() async {
        if let discovered, let idToken = tokens?.idToken,
           let url = try? Self.url(discovered.endSessionEndpoint, queryItems: [
               URLQueryItem(name: "id_token_hint", value: idToken),
               URLQueryItem(
                   name: "post_logout_redirect_uri",
                   value: configuration.postLogoutRedirectURI.absoluteString
               ),
           ]) {
            _ = try? await webAuthenticator.authenticate(
                url: url,
                callbackScheme: configuration.postLogoutRedirectURI.scheme ?? "floormobile"
            )
        }
        refreshTask?.cancel()
        refreshTask = nil
        tokens = nil
        try? await store.clear()
        AppLog.auth.info("Signed out")
    }

    // MARK: - Refresh (single-flight)

    private func refreshedTokens() async throws -> TokenSet {
        // A refresh already in flight is shared: concurrent callers await
        // the same Task instead of starting their own.
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> TokenSet {
        guard let current = tokens else {
            throw AppError.authentication(.sessionExpired)
        }
        let oidc = try await discover()
        do {
            let refreshed = try await requestTokens(endpoint: oidc.tokenEndpoint, body: [
                "grant_type": "refresh_token",
                "refresh_token": current.refreshToken,
                "client_id": configuration.clientID,
            ])
            // Zitadel rotates refresh tokens: persist the new one BEFORE
            // declaring success, or a crash would strand a dead token.
            try await store.save(refreshed)
            tokens = refreshed
            return refreshed
        } catch AppError.server(let statusCode) where statusCode == 400 || statusCode == 401 {
            // invalid_grant: the refresh token is dead — wipe the session.
            tokens = nil
            try? await store.clear()
            AppLog.auth.info("Refresh rejected, session wiped")
            throw AppError.authentication(.sessionExpired)
        }
    }

    // MARK: - Networking

    private func discover() async throws -> OIDCConfiguration {
        if let discovered {
            return discovered
        }
        let config = try await OIDCConfiguration.fetch(
            issuer: configuration.issuer,
            session: urlSession
        )
        discovered = config
        return config
    }

    private func requestTokens(endpoint: URL, body: [String: String]) async throws -> TokenSet {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(body).utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw AppError.network(underlying: error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network(underlying: nil)
        }
        guard http.statusCode == 200 else {
            throw AppError.server(statusCode: http.statusCode)
        }
        do {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            return TokenSet(response: tokenResponse, now: now())
        } catch {
            throw AppError.decoding(underlying: error)
        }
    }

    // MARK: - Helpers

    private static func url(_ base: URL, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw AppError.unexpected(description: "Unbuildable URL from \(base)")
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw AppError.unexpected(description: "Unbuildable URL from \(base)")
        }
        return url
    }

    private static func authorizationCode(from callback: URL, expectedState: String) throws -> String {
        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "state" })?.value == expectedState,
              let code = items.first(where: { $0.name == "code" })?.value
        else {
            throw AppError.authentication(.invalidCallback)
        }
        return code
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        return Data(bytes).base64URLEncodedString()
    }

    private static func formEncode(_ parameters: [String: String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return parameters
            .map { key, value in
                "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
            }
            .joined(separator: "&")
    }
}
