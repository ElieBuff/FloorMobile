//
//  PKCE.swift
//  FloorMobile
//

import CryptoKit
import Foundation

/// PKCE verifier/challenge pair (RFC 7636, S256 method).
nonisolated struct PKCE: Sendable {
    let verifier: String
    let challenge: String

    /// Generates a random verifier (43 base64url characters from 32 random bytes).
    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        self.init(verifier: Data(bytes).base64URLEncodedString())
    }

    /// Deterministic variant, used by tests against the RFC reference vector.
    init(verifier: String) {
        self.verifier = verifier
        let digest = SHA256.hash(data: Data(verifier.utf8))
        self.challenge = Data(digest).base64URLEncodedString()
    }
}

extension Data {
    /// Base64url without padding (RFC 4648 §5).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
