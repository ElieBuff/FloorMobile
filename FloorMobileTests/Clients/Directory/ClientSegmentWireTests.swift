//
//  ClientSegmentWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client segment wire")
struct ClientSegmentWireTests {

    private static func segments() throws -> [ClientSegmentWire.Response] {
        try APIClient.makeDecoder()
            .decode(SetupWire.Response.self, from: try Fixture.data("setup"))
            .clientConfiguration.segments
    }

    @Test("The setup's segments decode in the brand's order, with their colours")
    func setupDecodes() throws {
        let segments = try Self.segments()

        #expect(segments.map(\.code) == ["One Timer", "Connoisseur", "VIP", "VIC"])
        #expect(segments.last?.style.backgroundColor == "#14545F")
        #expect(segments.last?.style.textColor == "#ffffff")
    }

    @Test("A segment the console has not coloured comes as an empty style")
    func emptyStyle() throws {
        let json = Data(#"{ "code": "Explorer", "style": {} }"#.utf8)

        let wire = try APIClient.makeDecoder().decode(ClientSegmentWire.Response.self, from: json)

        #expect(wire.code == "Explorer")
        #expect(wire.style.backgroundColor == nil)
        #expect(wire.style.textColor == nil)
    }

    @Test("A segment maps with its colours, raw, and the rank it is given")
    func segmentMaps() throws {
        let wire = try #require(try Self.segments().first { $0.code == "Connoisseur" })

        let segment = ClientSegment(wire: wire, rank: 1)

        #expect(segment.code == "Connoisseur")
        #expect(segment.backgroundColorHex == "#1454600D")
        #expect(segment.textColorHex == "#2A5A63")
        #expect(segment.rank == 1)
    }
}
