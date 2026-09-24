//
//  AIActionEndpointTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AIAction endpoint")
struct AIActionEndpointTests {

    @Test("Pending AI actions: a bare GET on the BFF path, no query, no body")
    func pendingActionsEndpoint() {
        let endpoint = Endpoint.getPendingActions()

        #expect(endpoint.path == "ai-action/pending")
        #expect(endpoint.method == .get)
        #expect(endpoint.query.isEmpty)
        #expect(endpoint.body == nil)
    }
}
