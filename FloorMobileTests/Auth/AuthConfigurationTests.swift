//
//  AuthConfigurationTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AuthConfiguration")
struct AuthConfigurationTests {

    private static let validInfo: [String: Any] = [
        "AuthIssuer": "https://dev-q7qkap.eu1.zitadel.cloud",
        "AuthClientID": "389695826299033234",
        "AuthProjectID": "378848396062002729",
    ]

    @Test("Builds from a complete Info.plist dictionary")
    func buildsFromFullInfo() throws {
        let config = try AuthConfiguration(info: Self.validInfo)

        #expect(config.issuer.absoluteString == "https://dev-q7qkap.eu1.zitadel.cloud")
        #expect(config.clientID == "389695826299033234")
        #expect(config.scopes.contains("urn:zitadel:iam:org:project:id:378848396062002729:aud"))
        #expect(config.redirectURI.scheme == "floormobile")
    }

    @Test("A missing key is rejected", arguments: ["AuthIssuer", "AuthClientID", "AuthProjectID"])
    func missingKeyIsRejected(key: String) {
        var info = Self.validInfo
        info.removeValue(forKey: key)

        #expect(throws: AppError.self) {
            _ = try AuthConfiguration(info: info)
        }
    }

    @Test("An empty value — the unassigned-xcconfig case — is rejected")
    func emptyValueIsRejected() {
        var info = Self.validInfo
        info["AuthIssuer"] = ""

        #expect(throws: AppError.self) {
            _ = try AuthConfiguration(info: info)
        }
    }

    @Test("A non-HTTPS issuer is rejected")
    func nonHTTPSIssuerIsRejected() {
        var info = Self.validInfo
        info["AuthIssuer"] = "http://insecure.example.com"

        #expect(throws: AppError.self) {
            _ = try AuthConfiguration(info: info)
        }
    }
}
