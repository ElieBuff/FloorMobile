//
//  ClientFilterWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client filter wire")
struct ClientFilterWireTests {

    private static func setup() throws -> SetupWire.Response {
        try APIClient.makeDecoder().decode(SetupWire.Response.self, from: try Fixture.data("setup"))
    }

    @Test("The setup's filters decode with their values, in the server's order")
    func setupDecodes() throws {
        let filters = try Self.setup().clients.filters

        #expect(filters.map(\.id) == ["01M5CJ75QEKQR98JVNHCZ675TN", "01M5CJ75QP16918M3WRY9FYBEB"])
        #expect(filters.allSatisfy { $0.values.count == 4 && $0.selection == "SINGLE" })
    }

    @Test("A filter maps with its rank, and a value with its date parameter")
    func filterMaps() throws {
        let wire = try #require(try Self.setup().clients.filters.last)

        let filter = ClientFilter(wire: wire, rank: 1)

        #expect(filter.id == "01M5CJ75QP16918M3WRY9FYBEB")
        #expect(filter.titleKey == "client.filter.lastPurchase")
        #expect(filter.rank == 1)
        let since = try #require(filter.values.last)
        #expect(since.labelKey == "client.filter.value.since")
        #expect(since.label == nil)
        #expect(since.parameters == [ClientFilterValue.Parameter(name: "since", typeRaw: "date")])
    }

    @Test("A value generated from a list carries its label as is, with no key")
    func labelledValueMaps() throws {
        let json = Data(#"{"ref": "r1", "parameters": [], "label": "Gold"}"#.utf8)

        let value = ClientFilterValue(wire: try JSONDecoder().decode(ClientFilterWire.Value.self, from: json))

        #expect(value == ClientFilterValue(ref: "r1", labelKey: nil, label: "Gold", parameters: []))
    }
}
