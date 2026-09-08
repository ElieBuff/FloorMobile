//
//  AppSessionTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@MainActor
@Suite("AppSession")
struct AppSessionTests {

    @Test("Launch with a persisted session goes straight to authenticated")
    func restoreGoesToAuthenticated() async throws {
        let claims = try Self.claims(["sub": "u-1", "name": "Marie"])
        let session = AppSession(auth: Self.client(restore: { claims }))

        await session.start()

        let user = try #require(User(claims: claims))
        #expect(session.state == .authenticated(user))
    }

    @Test("Launch with an empty Keychain goes to unauthenticated")
    func emptyRestoreGoesToUnauthenticated() async {
        let session = AppSession(auth: Self.client(restore: { nil }))
        await session.start()
        #expect(session.state == .unauthenticated)
    }

    @Test("Successful sign-in exposes the mapped user")
    func signInSuccess() async throws {
        let claims = try Self.claims(["sub": "u-2", "email": "paul@example.com"])
        let session = AppSession(auth: Self.client(signIn: { claims }))

        await session.signIn()

        guard case .authenticated(let user) = session.state else {
            Issue.record("Expected authenticated, got \(session.state)")
            return
        }
        #expect(user.id == "u-2")
        #expect(user.name == "paul@example.com")
    }

    @Test("A cancelled sign-in returns to unauthenticated without an error")
    func cancelledSignIn() async {
        let session = AppSession(auth: Self.client(
            signIn: { throw AppError.authentication(.userCancelled) }
        ))

        await session.signIn()

        #expect(session.state == .unauthenticated)
    }

    @Test("A failed sign-in surfaces a user-facing message")
    func failedSignIn() async {
        let session = AppSession(auth: Self.client(
            signIn: { throw AppError.network(underlying: nil) }
        ))

        await session.signIn()

        guard case .failed(let message) = session.state else {
            Issue.record("Expected failed, got \(session.state)")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test("Sign-out forwards to the auth client and resets the state")
    func signOutResets() async throws {
        try await confirmation("signOut forwarded") { confirm in
            let claims = try Self.claims(["sub": "u-3"])
            let session = AppSession(auth: Self.client(
                restore: { claims },
                signOut: { confirm() }
            ))
            await session.start()

            await session.signOut()

            #expect(session.state == .unauthenticated)
        }
    }

    // MARK: - Helpers

    private static func client(
        restore: @Sendable @escaping () async -> IDTokenClaims? = { nil },
        signIn: @Sendable @escaping () async throws -> IDTokenClaims = {
            throw AppError.unexpected(description: "signIn not stubbed")
        },
        signOut: @Sendable @escaping () async -> Void = {}
    ) -> AuthClient {
        AuthClient(restore: restore, signIn: signIn, signOut: signOut)
    }

    private nonisolated static func claims(_ payload: [String: Any]) throws -> IDTokenClaims {
        let header = Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8)
        let body = try JSONSerialization.data(withJSONObject: payload)
        let idToken = [header, body, Data("sig".utf8)]
            .map { $0.base64URLEncodedString() }
            .joined(separator: ".")
        return try IDTokenClaims(idToken: idToken)
    }
}
