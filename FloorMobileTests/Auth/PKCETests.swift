//
//  PKCETests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("PKCE")
struct PKCETests {

    @Test("RFC 7636 reference vector produces the expected challenge")
    func rfcReferenceVector() {
        // Reference values from RFC 7636, appendix B.
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("Generated verifiers are unique")
    func generatedVerifiersAreUnique() {
        let first = PKCE()
        let second = PKCE()
        #expect(first.verifier != second.verifier)
    }

    @Test("Generated verifier respects RFC length and charset")
    func generatedVerifierFormat() {
        let pkce = PKCE()
        #expect(pkce.verifier.count >= 43 && pkce.verifier.count <= 128)

        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        #expect(pkce.verifier.unicodeScalars.allSatisfy(allowed.contains))
    }
}
