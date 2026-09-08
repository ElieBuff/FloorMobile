//
//  TokenSetTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("TokenSet")
struct TokenSetTests {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    // The fixture follows the documented Zitadel token response shape;
    // a real capture requires a completed login and will replace it later.
    @Test("Token response decodes and computes the expiry date")
    func decodesTokenResponse() throws {
        let data = try Fixture.data("token_response")
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = TokenSet(response: response, now: now)

        #expect(tokens.accessToken == "test-access-token")
        #expect(tokens.refreshToken == "test-refresh-token")
        #expect(tokens.idToken == "test-id-token")
        #expect(tokens.expiresAt == now.addingTimeInterval(43_199))
    }

    @Test("Expiry margin: a token dying within the margin is not valid")
    func expiryMargin() {
        let tokens = TokenSet(
            accessToken: "a", refreshToken: "r", idToken: "i",
            expiresAt: now.addingTimeInterval(60)
        )
        // 59 s before expiry: inside the 60 s margin, treated as expired.
        #expect(!tokens.isValid(now: now.addingTimeInterval(1)))
        // 61 s before expiry: outside the margin, still valid.
        let valid = TokenSet(
            accessToken: "a", refreshToken: "r", idToken: "i",
            expiresAt: now.addingTimeInterval(61)
        )
        #expect(valid.isValid(now: now))
    }

    @Test("ID token claims are extracted from the payload")
    func decodesClaims() throws {
        let idToken = Self.jwt(payload: [
            "sub": "user-123",
            "name": "Marie Martin",
            "email": "marie@example.com",
            "nonce": "expected-nonce",
            "urn:zitadel:iam:user:resourceowner:id": "org-42",
        ])
        let claims = try IDTokenClaims(idToken: idToken)

        #expect(claims.subject == "user-123")
        #expect(claims.name == "Marie Martin")
        #expect(claims.email == "marie@example.com")
        #expect(claims.tenantID == "org-42")
        try claims.validateNonce("expected-nonce")
    }

    @Test("A nonce mismatch is rejected")
    func rejectsWrongNonce() throws {
        let idToken = Self.jwt(payload: ["nonce": "expected-nonce"])
        let claims = try IDTokenClaims(idToken: idToken)

        #expect(throws: AppError.self) {
            try claims.validateNonce("a-different-nonce")
        }
    }

    @Test("A malformed ID token is rejected")
    func rejectsMalformedToken() {
        #expect(throws: AppError.self) {
            _ = try IDTokenClaims(idToken: "not-a-jwt")
        }
    }

    /// Builds an unsigned JWT with the given payload (signature is not
    /// verified on-device, so any value works for the third segment).
    private static func jwt(payload: [String: Any]) -> String {
        let header = Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8)
        let body = try! JSONSerialization.data(withJSONObject: payload)
        return [header, body, Data("sig".utf8)]
            .map { $0.base64URLEncodedString() }
            .joined(separator: ".")
    }
}
