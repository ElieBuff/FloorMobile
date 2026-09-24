//
//  EnumsEndpointTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A path is a string the compiler never checks. `AIActionEndpointTests` and
/// `AgendaEndpointTests` pin theirs; this one was the last without.
@Suite("Enums endpoint")
struct EnumsEndpointTests {

    @Test("The vocabulary is fetched from `enums`, with nothing else attached")
    func pathAndShape() {
        let endpoint = Endpoint.enums()

        #expect(endpoint.path == "enums")
        #expect(endpoint.method == .get)
        // No query and no body: the whole map comes at once, unpaginated.
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body == nil)
    }
}
