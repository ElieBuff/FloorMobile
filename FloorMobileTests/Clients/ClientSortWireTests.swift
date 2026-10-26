//
//  ClientSortWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client sort wire")
struct ClientSortWireTests {

    private static func sorts() throws -> [ClientSortWire.Response] {
        try APIClient.makeDecoder().decode(SetupWire.Response.self, from: try Fixture.data("setup")).clients.sorts
    }

    @Test("The setup's sorts decode in their positions, the name by default")
    func setupDecodes() throws {
        let sorts = try Self.sorts()

        #expect(sorts.map(\.value) == ["name", "lastPurchase", "spent12M", "spentLifetime", "createdDate", "contactedByMe"])
        #expect(sorts.map(\.position) == Array(0..<6))
        #expect(sorts.filter(\.isDefault).map(\.value) == ["name"])
    }

    @Test("A sort maps with its direction and its position as rank")
    func sortMaps() throws {
        let wire = try #require(try Self.sorts().first { $0.value == "lastPurchase" })

        let sort = ClientSort(wire: wire)

        #expect(sort.labelKey == "client.sort.lastPurchase")
        #expect(sort.directionRaw == "desc")
        #expect(sort.direction == .desc)
        #expect(sort.isDefault == false)
        #expect(sort.rank == 1)
    }
}
