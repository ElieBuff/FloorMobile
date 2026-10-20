//
//  SetupEndpointTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A path is a string the compiler never checks: pinned here, like the other
/// endpoints'.
@Suite("Setup endpoint")
struct SetupEndpointTests {

    @Test("The configuration is fetched from `setup`, with nothing else attached")
    func pathAndShape() {
        let endpoint = Endpoint.setup()

        #expect(endpoint.path == "setup")
        #expect(endpoint.method == .get)
        // No query and no body: the whole configuration comes at once.
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body == nil)
    }
}
