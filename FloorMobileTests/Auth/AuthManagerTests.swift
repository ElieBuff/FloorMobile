//
//  AuthManagerTests.swift
//  FloorMobileTests
//

import Foundation
import Synchronization
import Testing
@testable import FloorMobile

// Serialized because MockURLProtocol.handler is shared static state — the
// one deviation the testing skill allows.
@Suite("AuthManager", .serialized)
struct AuthManagerTests {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Sign-in

    @Test("Sign-in exchanges the code, checks the nonce and persists the tokens")
    func signInHappyPath() async throws {
        let stub = StubWebAuthenticator()
        let store = InMemoryTokenStore()
        let manager = makeManager(stub: stub, store: store)
        let discoveryData = try Fixture.data("openid_configuration")

        MockURLProtocol.handler = { request in
            if Self.isDiscovery(request) {
                return (Self.ok(request), discoveryData)
            }
            // Token endpoint: echo the nonce captured from the authorize URL.
            return (Self.ok(request), Self.tokenJSON(nonce: stub.sentNonce))
        }

        let claims = try await manager.signIn()

        #expect(claims.nonce == stub.sentNonce)
        #expect(await store.stored?.accessToken == "at-1")
        #expect(await store.saveCount == 1)

        // The authorization request carries the full PKCE + OIDC parameters.
        let query = try #require(stub.authorizationURL?.query())
        #expect(query.contains("code_challenge_method=S256"))
        #expect(query.contains("response_type=code"))

        // The freshly obtained token is served without any refresh.
        #expect(try await manager.validToken() == "at-1")
    }

    @Test("A tampered state in the callback is rejected")
    func tamperedStateIsRejected() async throws {
        let stub = StubWebAuthenticator()
        stub.forcedState = "evil-state"
        let store = InMemoryTokenStore()
        let manager = makeManager(stub: stub, store: store)
        let discoveryData = try Fixture.data("openid_configuration")

        MockURLProtocol.handler = { request in
            (Self.ok(request), Self.isDiscovery(request) ? discoveryData : Self.tokenJSON(nonce: nil))
        }

        await #expect(throws: AppError.self) {
            _ = try await manager.signIn()
        }
        #expect(await store.stored == nil)
    }

    // MARK: - validToken

    @Test("A valid token is returned without touching the network")
    func validTokenSkipsNetwork() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenSet(
            accessToken: "seeded-token", refreshToken: "rt", idToken: "id",
            expiresAt: now.addingTimeInterval(3_600)
        ))
        let manager = makeManager(stub: StubWebAuthenticator(), store: store)

        let requestCount = Mutex(0)
        MockURLProtocol.handler = { request in
            requestCount.withLock { $0 += 1 }
            return (Self.ok(request), Data())
        }

        #expect(try await manager.validToken() == "seeded-token")
        #expect(requestCount.withLock { $0 } == 0)
    }

    @Test("Two concurrent validToken() on an expired token trigger exactly one refresh")
    func singleFlightRefresh() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenSet(
            accessToken: "expired-token", refreshToken: "rt-old", idToken: "id",
            expiresAt: now
        ))
        let manager = makeManager(stub: StubWebAuthenticator(), store: store)
        let discoveryData = try Fixture.data("openid_configuration")

        let refreshCount = Mutex(0)
        MockURLProtocol.handler = { request in
            if Self.isDiscovery(request) {
                return (Self.ok(request), discoveryData)
            }
            refreshCount.withLock { $0 += 1 }
            // Widen the concurrency window: the second caller arrives while
            // the first refresh is still in flight.
            Thread.sleep(forTimeInterval: 0.05)
            return (Self.ok(request), Self.tokenJSON(
                nonce: nil, accessToken: "at-new", refreshToken: "rt-new"
            ))
        }

        async let first = manager.validToken()
        async let second = manager.validToken()
        let tokens = try await (first, second)

        #expect(tokens.0 == "at-new")
        #expect(tokens.1 == "at-new")
        #expect(refreshCount.withLock { $0 } == 1)

        // The rotated refresh token was persisted (seed save + refresh save).
        #expect(await store.stored?.refreshToken == "rt-new")
        #expect(await store.saveCount == 2)
    }

    @Test("A refresh refused by the identity provider wipes the session")
    func refusedRefreshWipesSession() async throws {
        let store = InMemoryTokenStore()
        try await store.save(TokenSet(
            accessToken: "expired-token", refreshToken: "rt-dead", idToken: "id",
            expiresAt: now
        ))
        let manager = makeManager(stub: StubWebAuthenticator(), store: store)
        let discoveryData = try Fixture.data("openid_configuration")

        MockURLProtocol.handler = { request in
            if Self.isDiscovery(request) {
                return (Self.ok(request), discoveryData)
            }
            return (Self.response(request, statusCode: 400), Data())
        }

        await #expect(throws: AppError.self) {
            _ = try await manager.validToken()
        }
        #expect(await store.stored == nil)
    }

    // MARK: - Helpers

    private func makeManager(stub: StubWebAuthenticator, store: InMemoryTokenStore) -> AuthManager {
        AuthManager(
            store: store,
            webAuthenticator: stub,
            urlSession: MockURLProtocol.session(),
            now: { [now] in now }
        )
    }

    private nonisolated static func isDiscovery(_ request: URLRequest) -> Bool {
        request.url?.path().contains("openid-configuration") == true
    }

    private nonisolated static func ok(_ request: URLRequest) -> HTTPURLResponse {
        response(request, statusCode: 200)
    }

    private nonisolated static func response(_ request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url ?? URL(string: "https://invalid")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    /// Token endpoint response whose ID token carries the given nonce.
    private nonisolated static func tokenJSON(
        nonce: String?,
        accessToken: String = "at-1",
        refreshToken: String = "rt-1"
    ) -> Data {
        var payload: [String: Any] = ["sub": "user-123"]
        if let nonce {
            payload["nonce"] = nonce
        }
        let header = Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8)
        let body = try! JSONSerialization.data(withJSONObject: payload)
        let idToken = [header, body, Data("sig".utf8)]
            .map { $0.base64URLEncodedString() }
            .joined(separator: ".")

        let json: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "id_token": idToken,
            "expires_in": 3_600,
            "token_type": "Bearer",
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }
}
