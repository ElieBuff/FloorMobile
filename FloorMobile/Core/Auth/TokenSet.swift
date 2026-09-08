//
//  TokenSet.swift
//  FloorMobile
//

import Foundation

/// The three tokens returned by Zitadel plus the computed expiry date.
///
/// Kept as one unit so that a refresh — which rotates the refresh token —
/// is persisted atomically: all three tokens or nothing.
nonisolated struct TokenSet: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let expiresAt: Date

    init(accessToken: String, refreshToken: String, idToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
    }

    init(response: TokenResponse, now: Date) {
        self.init(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            idToken: response.idToken,
            expiresAt: now.addingTimeInterval(TimeInterval(response.expiresIn))
        )
    }

    /// A token is treated as expired `margin` seconds before its real expiry,
    /// so a request never leaves with a token about to die in flight.
    func isValid(now: Date, margin: TimeInterval = 60) -> Bool {
        now.addingTimeInterval(margin) < expiresAt
    }
}

/// Raw token endpoint response.
nonisolated struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresIn = "expires_in"
    }
}

/// Claims read from the ID token payload.
///
/// The signature is deliberately NOT verified on-device: tokens arrive
/// straight from Zitadel over TLS and the backend validates them via JWKS.
/// Claims are used for display and session context only — never for security
/// decisions. The `nonce` claim MUST be checked against the value sent in
/// the authorization request.
nonisolated struct IDTokenClaims: Sendable {
    let subject: String?
    let name: String?
    let email: String?
    let nonce: String?
    /// Zitadel resource owner (organization) id — the tenant.
    let tenantID: String?

    init(idToken: String) throws {
        let segments = idToken.split(separator: ".")
        guard segments.count == 3,
              let payload = Data(base64URLEncoded: String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else {
            throw AppError.authentication(.invalidCallback)
        }
        subject = json["sub"] as? String
        name = json["name"] as? String
        email = json["email"] as? String
        nonce = json["nonce"] as? String
        tenantID = json["urn:zitadel:iam:user:resourceowner:id"] as? String
    }

    /// Throws when the token's nonce does not match the one we generated.
    func validateNonce(_ expected: String) throws {
        guard nonce == expected else {
            throw AppError.authentication(.invalidCallback)
        }
    }
}

extension Data {
    /// Decodes base64url (RFC 4648 §5), re-adding the stripped padding.
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        self.init(base64Encoded: base64)
    }
}
