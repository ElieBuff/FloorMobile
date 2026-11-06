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
        let session = Self.session(auth: Self.client(restore: { claims }), api: Self.stubAPIClient())

        await session.start()

        let user = try #require(User(claims: claims))
        #expect(session.state == .authenticated(user))
    }

    @Test("Launch with an empty Keychain goes to unauthenticated")
    func emptyRestoreGoesToUnauthenticated() async {
        let session = Self.session(auth: Self.client(restore: { nil }), api: Self.stubAPIClient())
        await session.start()
        #expect(session.state == .unauthenticated)
    }

    @Test("Successful sign-in exposes the mapped user")
    func signInSuccess() async throws {
        let claims = try Self.claims(["sub": "u-2", "email": "paul@example.com"])
        let session = Self.session(auth: Self.client(signIn: { claims }), api: Self.stubAPIClient())

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
        let session = AppSession(
            auth: Self.client(signIn: { throw AppError.authentication(.userCancelled) }),
            api: Self.stubAPIClient()
        )

        await session.signIn()

        #expect(session.state == .unauthenticated)
    }

    @Test("A failed sign-in surfaces a user-facing message")
    func failedSignIn() async {
        let session = AppSession(
            auth: Self.client(signIn: { throw AppError.network(underlying: nil) }),
            api: Self.stubAPIClient()
        )

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
            let session = AppSession(
                auth: Self.client(restore: { claims }, signOut: { confirm() }),
                api: Self.stubAPIClient()
            )
            await session.start()

            await session.signOut()

            #expect(session.state == .unauthenticated)
        }
    }

    @Test("start() is a no-op once the session has left the loading state")
    func startIsIdempotentAfterSignIn() async throws {
        let claims = try Self.claims(["sub": "u-9"])
        // restore would unauthenticate (returns nil) if start() weren't guarded.
        let session = AppSession(
            auth: Self.client(restore: { nil }, signIn: { claims }),
            api: Self.stubAPIClient()
        )
        await session.signIn()
        guard case .authenticated = session.state else {
            Issue.record("Precondition: expected authenticated after signIn")
            return
        }

        await session.start()

        guard case .authenticated = session.state else {
            Issue.record("start() overwrote an already-authenticated session")
            return
        }
    }

    // MARK: - Associate signed in

    @Test("A new session on an empty store has no associate")
    func noAssociateAtFirst() {
        let session = Self.session(auth: Self.client(), api: Self.stubAPIClient())

        #expect(session.salesAssociate == nil)
        #expect(session.store == nil)
    }

    @Test("The associate kept is there at the next launch, with their store")
    func keptAssociateSurvivesALaunch() {
        let associateStorage = StoredValue<SalesAssociateSnapshot>.inMemory()
        let storeStorage = StoredValue<StoreSnapshot>.inMemory()
        let associate = SalesAssociateSnapshot(id: "sa-1", firstName: "Elie", lastName: "Buff", preferredLanguage: "Fr")
        let store = StoreSnapshot(id: "s-1", name: "Shop location", storeCode: "90917634296")

        Self.session(
            auth: Self.client(), api: Self.stubAPIClient(),
            salesAssociateStorage: associateStorage, storeStorage: storeStorage
        )
        .keep(associate, store: store)
        let next = Self.session(
            auth: Self.client(), api: Self.stubAPIClient(),
            salesAssociateStorage: associateStorage, storeStorage: storeStorage
        )

        #expect(next.salesAssociate == associate)
        #expect(next.store == store)
    }

    @Test("Signing out forgets the associate, in memory and on the device")
    func signOutForgetsTheAssociate() async {
        let associateStorage = StoredValue<SalesAssociateSnapshot>.inMemory(SalesAssociateSnapshot(id: "sa-1"))
        let storeStorage = StoredValue<StoreSnapshot>.inMemory(StoreSnapshot(id: "s-1"))
        let session = Self.session(
            auth: Self.client(), api: Self.stubAPIClient(),
            salesAssociateStorage: associateStorage, storeStorage: storeStorage
        )

        await session.signOut()

        #expect(session.salesAssociate == nil)
        #expect(session.store == nil)
        #expect(associateStorage.get() == nil)
        #expect(storeStorage.get() == nil)
    }

    // MARK: - Helpers

    /// A session whose associate is kept in memory: the tests never read or
    /// write the simulator's `UserDefaults`.
    private static func session(
        auth: AuthClient,
        api: APIClient,
        salesAssociateStorage: StoredValue<SalesAssociateSnapshot> = .inMemory(),
        storeStorage: StoredValue<StoreSnapshot> = .inMemory()
    ) -> AppSession {
        AppSession(auth: auth, api: api, salesAssociateStorage: salesAssociateStorage, storeStorage: storeStorage)
    }

    private static func stubAPIClient() -> APIClient {
        APIClient(
            baseURL: URL(string: "https://stub.example.com")!,
            tokens: TokenProviding(
                validToken: { throw AppError.unexpected(description: "unexpected call") },
                refreshedToken: { throw AppError.unexpected(description: "unexpected call") }
            )
        )
    }

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
