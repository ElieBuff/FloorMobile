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
        let filters = try Self.setup().clientConfiguration.filters

        #expect(filters.map(\.id) == ["01M5CJ75QEKQR98JVNHCZ675TN", "01M5CJ75QP16918M3WRY9FYBEB"])
        #expect(filters.allSatisfy { $0.values.count == 4 && $0.selection == "SINGLE" })
    }

    @Test("A filter maps with its rank, and a value with its date parameter")
    func filterMaps() throws {
        let wire = try #require(try Self.setup().clientConfiguration.filters.last)

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

    @Test("A filter generated from a list carries the field its values come from")
    func generatedFilterMapsItsValueField() throws {
        // The Tier as `GET setup` served it on 18/11, with the `valueField` the server
        // is to add: to replace with a real response once it is served.
        let json = Data(#"""
        {
            "id": "01M7MT3J54JNQTQ2Y8GWMHHBQC", "titleKey": "client.filter.tier", "selection": "MULTIPLE",
            "valueField": "client.segment",
            "values": [{"ref": "01M7MT3J54JNQTQ2Y8GWMHHBQC:VIP", "parameters": [], "label": "VIP"}]
        }
        """#.utf8)

        let filter = ClientFilter(wire: try JSONDecoder().decode(ClientFilterWire.Response.self, from: json), rank: 0)

        #expect(filter.valueFieldRaw == "client.segment")
        #expect(filter.valueField == .segment)
        #expect(filter.values.map(\.label) == ["VIP"])
    }

    @Test("A filter written by hand has no value field")
    func handWrittenFilterHasNoValueField() throws {
        let filters = try Self.setup().clientConfiguration.filters

        #expect(filters.allSatisfy { ClientFilter(wire: $0, rank: 0).valueFieldRaw == nil })
    }
}
