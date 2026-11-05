//
//  ClientDetailsTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// How a client's details read on screen — salutation, language, address —,
/// on the details the local BFF served for a seeded client
/// (`client_details.json`, captured on 04/11/2026). That client has none of
/// the three: each test sets what it reads on the decoded wire.
@Suite("Client details")
struct ClientDetailsTests {

    /// The captured details, decoded the way `APIClient` decodes them.
    private static func wire() throws -> ClientDetailsWire.Response {
        try APIClient.makeDecoder().decode(ClientDetailsWire.Response.self, from: try Fixture.data("client_details"))
    }

    @Test(
        "A salutation reads as its title; one this build does not know, or none, shows nothing",
        arguments: [("mister", "Mr"), ("misses", "Mrs"), ("miss", "Miss"), ("doctor", nil), (nil, nil)] as [(String?, String?)]
    )
    func salutationLabel(salutation: String?, label: String?) throws {
        var wire = try Self.wire()
        wire.salutation = salutation

        #expect(ClientDetails(wire: wire).salutationLabel == label)
    }

    @Test("A language reads as its name in the device's language")
    func languageName() throws {
        var wire = try Self.wire()
        wire.preferredLanguage = "fr"

        #expect(ClientDetails(wire: wire).languageName == Locale.current.localizedString(forLanguageCode: "fr"))
        #expect(ClientDetails(wire: try Self.wire()).languageName == nil)
    }

    @Test("An address reads line by line, the postal code beside the city and the country named")
    func addressLines() throws {
        var wire = try Self.wire()
        wire.mainAddress = ClientDetailsWire.Address(
            street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
        )

        let lines = try #require(ClientDetails(wire: wire).address).lines

        #expect(lines == ["Rua Garrett 50", "1200-204 Lisboa", Locale.current.localizedString(forRegionCode: "PT")!])
    }

    @Test("An address leaves out what the source left empty, and keeps a country it wrote as a name")
    func addressSkipsEmptyLines() throws {
        var wire = try Self.wire()
        wire.mainAddress = ClientDetailsWire.Address(
            street: "", postalCode: nil, city: "Lisboa", state: nil, country: "Portugal"
        )

        let lines = try #require(ClientDetails(wire: wire).address).lines

        #expect(lines == ["Lisboa", "Portugal"])
    }
}
