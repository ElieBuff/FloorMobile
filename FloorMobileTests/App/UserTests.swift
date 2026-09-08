//
//  UserTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("User")
struct UserTests {

    @Test("Maps every claim, tenant included")
    func fullMapping() throws {
        let user = try #require(User(claims: Self.claims([
            "sub": "u-1",
            "name": "Marie Martin",
            "email": "marie@example.com",
            "urn:zitadel:iam:user:resourceowner:id": "org-42",
        ])))

        #expect(user.id == "u-1")
        #expect(user.name == "Marie Martin")
        #expect(user.email == "marie@example.com")
        #expect(user.tenantID == "org-42")
    }

    @Test("Display name falls back to email, then to the subject")
    func nameFallbacks() throws {
        let emailOnly = try #require(User(claims: Self.claims([
            "sub": "u-1", "email": "marie@example.com",
        ])))
        #expect(emailOnly.name == "marie@example.com")

        let bare = try #require(User(claims: Self.claims(["sub": "u-1"])))
        #expect(bare.name == "u-1")
    }

    @Test("Claims without a subject produce no user")
    func missingSubject() throws {
        let claims = try Self.claims(["name": "Ghost"])
        #expect(User(claims: claims) == nil)
    }

    // MARK: - Helpers

    private nonisolated static func claims(_ payload: [String: Any]) throws -> IDTokenClaims {
        let header = Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8)
        let body = try JSONSerialization.data(withJSONObject: payload)
        let idToken = [header, body, Data("sig".utf8)]
            .map { $0.base64URLEncodedString() }
            .joined(separator: ".")
        return try IDTokenClaims(idToken: idToken)
    }
}
