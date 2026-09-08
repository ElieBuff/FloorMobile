//
//  OIDCDiscoveryTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("OIDC discovery")
struct OIDCDiscoveryTests {

    // The fixture is a copy of the real response from
    // https://dev-q7qkap.eu1.zitadel.cloud/.well-known/openid-configuration
    // (captured 2026-09-07).
    @Test("Discovery document decodes the three endpoints")
    func decodesEndpoints() throws {
        let data = try Fixture.data("openid_configuration")
        let config = try JSONDecoder().decode(OIDCConfiguration.self, from: data)

        #expect(config.authorizationEndpoint.absoluteString
            == "https://dev-q7qkap.eu1.zitadel.cloud/oauth/v2/authorize")
        #expect(config.tokenEndpoint.absoluteString
            == "https://dev-q7qkap.eu1.zitadel.cloud/oauth/v2/token")
        #expect(config.endSessionEndpoint.absoluteString
            == "https://dev-q7qkap.eu1.zitadel.cloud/oidc/v1/end_session")
    }

    @Test("Missing endpoint in the document fails decoding")
    func missingEndpointFails() throws {
        let json = #"{"authorization_endpoint": "https://example.com/authorize"}"#
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(OIDCConfiguration.self, from: Data(json.utf8))
        }
    }
}
