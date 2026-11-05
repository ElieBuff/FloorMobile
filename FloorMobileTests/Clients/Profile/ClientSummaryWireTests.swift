//
//  ClientSummaryWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// `client/{id}/summary` as the local BFF served it for a seeded client
/// (`client_summary.json`, captured on 04/11/2026): the five fields of the AI
/// summary.
@Suite("Client summary wire")
struct ClientSummaryWireTests {

    /// The captured summary, decoded the way `APIClient` decodes it.
    private static func wire() throws -> ClientSummaryWire.Response {
        try APIClient.makeDecoder().decode(ClientSummaryWire.Response.self, from: try Fixture.data("client_summary"))
    }

    @Test("The five fields map onto the summary, the mood typed")
    func fieldsMap() throws {
        let summary = ClientSummary(wire: try Self.wire())

        #expect(summary.title == "Outerwear-minded client awaiting a post-fitting call and birthday gesture")
        #expect(summary.brief.hasPrefix("Mme Dupont has been with the Maison since mid-2024"))
        #expect(summary.prose.hasPrefix("Her two baskets, in May and July 2024"))
        #expect(summary.nextStep.hasPrefix("Call Mme Dupont for the post-fitting follow-up"))
        #expect(summary.mood == .neutral)
    }

    @Test("A mood this build does not know leaves the summary without one")
    func unknownMoodIsNil() throws {
        // The server sends a known mood: an unknown one is set on the decoded wire.
        var wire = try Self.wire()
        wire.mood = "MIXED"

        let summary = ClientSummary(wire: wire)

        #expect(summary.mood == nil)
        #expect(summary.title == "Outerwear-minded client awaiting a post-fitting call and birthday gesture")
    }
}
