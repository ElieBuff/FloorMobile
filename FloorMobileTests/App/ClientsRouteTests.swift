//
//  ClientsRouteTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("ClientsRoute")
struct ClientsRouteTests {

    @Test("Routes are equal when they carry the same id, so the stack can diff them")
    func equality() {
        #expect(ClientsRoute.profile(id: "client-1") == ClientsRoute.profile(id: "client-1"))
        #expect(ClientsRoute.profile(id: "client-1") != ClientsRoute.profile(id: "client-2"))
    }

    @Test("A route round-trips through Codable, keeping its id — the basis for state restoration and deep links")
    func codableRoundTrip() throws {
        let route = ClientsRoute.profile(id: "client-1")
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(ClientsRoute.self, from: data)
        #expect(decoded == route)
    }

    @Test("A whole path round-trips through Codable in order")
    func pathRoundTrip() throws {
        let path: [ClientsRoute] = [.profile(id: "client-1"), .profile(id: "client-2")]
        let data = try JSONEncoder().encode(path)
        let decoded = try JSONDecoder().decode([ClientsRoute].self, from: data)
        #expect(decoded == path)
    }
}
