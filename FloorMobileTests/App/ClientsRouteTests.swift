//
//  ClientsRouteTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("ClientsRoute")
struct ClientsRouteTests {

    /// The row a list showed, carried along to the profile.
    private static let card = ClientItem(
        id: "client-1", displayName: "Alice Martinez", segment: "VIC",
        storeCode: "store-1", storeName: "Regent Street",
        salesAssociateExternalId: "sa-1", salesAssociateName: "Elie Buff",
        primaryEmail: "alice@example.com", primaryPhone: nil
    )

    @Test("Routes are equal when they carry the same id and the same card, so the stack can diff them")
    func equality() {
        #expect(ClientsRoute.profile(id: "client-1") == ClientsRoute.profile(id: "client-1"))
        #expect(ClientsRoute.profile(id: "client-1") != ClientsRoute.profile(id: "client-2"))
        #expect(
            ClientsRoute.profile(id: "client-1", card: Self.card) == ClientsRoute.profile(id: "client-1", card: Self.card)
        )
        #expect(ClientsRoute.profile(id: "client-1", card: Self.card) != ClientsRoute.profile(id: "client-1"))
    }

    @Test("A route round-trips through Codable, keeping its id — the basis for state restoration and deep links")
    func codableRoundTrip() throws {
        let route = ClientsRoute.profile(id: "client-1")
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(ClientsRoute.self, from: data)
        #expect(decoded == route)
    }

    @Test("A route round-trips through Codable with the card it carries")
    func codableRoundTripWithCard() throws {
        let route = ClientsRoute.profile(id: "client-1", card: Self.card)
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
