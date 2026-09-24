//
//  APIConfigurationTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The sibling of `AuthConfigurationTests`, and there for the same reason: the
/// base URL arrives through an xcconfig, an Info.plist variable and a string,
/// and every step of that chain fails silently if nobody looks.
@Suite("APIConfiguration")
struct APIConfigurationTests {

    // Computed, not `static let`: a shared [String: Any] is not Sendable.
    private var validInfo: [String: Any] {
        ["APIBaseURL": "https://bff.staging.floorapp.ai/api/secure/"]
    }

    @Test("Builds from a complete Info.plist dictionary")
    func buildsFromFullInfo() throws {
        let config = try APIConfiguration(info: validInfo)

        #expect(config.baseURL.absoluteString == "https://bff.staging.floorapp.ai/api/secure/")
    }

    @Test("A missing key is rejected")
    func missingKeyIsRejected() {
        #expect(throws: AppError.self) {
            _ = try APIConfiguration(info: [:])
        }
    }

    @Test("An empty value is rejected as firmly as a missing one")
    func emptyValueIsRejected() {
        // An unassigned xcconfig leaves the variable expanded to nothing, so
        // the empty string is the shape this failure actually takes.
        #expect(throws: AppError.self) {
            _ = try APIConfiguration(info: ["APIBaseURL": ""])
        }
    }

    @Test("A value of the wrong type is rejected")
    func nonStringValueIsRejected() {
        #expect(throws: AppError.self) {
            _ = try APIConfiguration(info: ["APIBaseURL": 42])
        }
    }

    @Test("The trailing slash is kept, since every path is appended to it")
    func trailingSlashSurvives() throws {
        let config = try APIConfiguration(info: validInfo)

        #expect(config.baseURL.absoluteString.hasSuffix("/"))
        #expect(config.baseURL.appending(path: "enums").absoluteString
            == "https://bff.staging.floorapp.ai/api/secure/enums")
    }
}
