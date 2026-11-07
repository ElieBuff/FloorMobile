//
//  ClientDetailsWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// `client/{id}` as the local BFF served it for a seeded client
/// (`client_details.json`, captured on 04/11/2026), read as the card the
/// profile shows, complete.
@Suite("Client details wire")
struct ClientDetailsWireTests {

    /// The captured details, decoded the way `APIClient` decodes them.
    private static func wire() throws -> ClientDetailsWire.Response {
        try APIClient.makeDecoder().decode(ClientDetailsWire.Response.self, from: try Fixture.data("client_details"))
    }

    @Test("The card reads the name, the email, the store and the associate from the details' own shape")
    func cardMaps() throws {
        let client = ClientItem(wire: try Self.wire())

        #expect(client.id == "001cfde7-0c26-48ae-990c-68bbd710211b")
        #expect(client.firstName == "Kimberly")
        #expect(client.lastName == "Robinson")
        #expect(client.primaryEmail == "kimberly.robinson1971@outlook.com")
        #expect(client.primaryPhone == nil)
        #expect(client.storeCode == "seed-store-28")
        #expect(client.storeName == "Emeria Lisbon")
        #expect(client.salesAssociateExternalId == "seed-sa-102")
        #expect(client.salesAssociateName == "Oliver Rossi")
    }

    @Test("A segment the server does not send yet leaves the card without one")
    func noSegmentYet() throws {
        #expect(ClientItem(wire: try Self.wire()).segment == nil)
    }

    @Test("The consents are read as sent")
    func optInsMap() throws {
        #expect(ClientItem(wire: try Self.wire()).optIns == ClientItem.OptIns(
            email: true, directMessage: true, call: true, wechat: false, line: false
        ))
    }

    @Test("A client without an address, salutation or language has none")
    func absentFieldsStayAbsent() throws {
        // The captured client has none of the three: the fixture as served.
        let client = ClientItem(wire: try Self.wire())

        #expect(client.address == nil)
        #expect(client.salutation == nil)
        #expect(client.preferredLanguage == nil)
    }

    @Test("An address, a salutation and a language are kept as sent")
    func presentFieldsMap() throws {
        // The captured client has none of them: they are set on the decoded wire.
        var wire = try Self.wire()
        wire.mainAddress = ClientWire.Address(
            street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
        )
        wire.salutation = "misses"
        wire.preferredLanguage = "pt"

        let client = ClientItem(wire: wire)

        #expect(client.address == ClientItem.Address(
            street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
        ))
        #expect(client.salutation == "misses")
        #expect(client.preferredLanguage == "pt")
    }
}
