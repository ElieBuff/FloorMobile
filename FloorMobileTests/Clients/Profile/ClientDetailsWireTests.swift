//
//  ClientDetailsWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// `client/{id}` as the local BFF served it for a seeded client
/// (`client_details.json`, captured on 04/11/2026), mapped onto the card the
/// profile shows and the details only it carries.
@Suite("Client details wire")
struct ClientDetailsWireTests {

    /// The captured details, decoded the way `APIClient` decodes them.
    private static func wire() throws -> ClientDetailsWire.Response {
        try APIClient.makeDecoder().decode(ClientDetailsWire.Response.self, from: try Fixture.data("client_details"))
    }

    @Test("The card reads the name, the email, the store and the associate from the details' own shape")
    func cardMaps() throws {
        let details = ClientDetails(wire: try Self.wire())

        #expect(details.id == "001cfde7-0c26-48ae-990c-68bbd710211b")
        #expect(details.client.displayName == "Kimberly Robinson")
        #expect(details.client.primaryEmail == "kimberly.robinson1971@outlook.com")
        #expect(details.client.primaryPhone == nil)
        #expect(details.client.storeCode == "seed-store-28")
        #expect(details.client.storeName == "Emeria Lisbon")
        #expect(details.client.salesAssociateExternalId == "seed-sa-102")
        #expect(details.client.salesAssociateName == "Oliver Rossi")
    }

    @Test("A segment the server does not send yet leaves the card without one")
    func noSegmentYet() throws {
        let details = ClientDetails(wire: try Self.wire())

        #expect(details.client.segment == nil)
    }

    @Test("The consents are read as sent")
    func optInsMap() throws {
        let details = ClientDetails(wire: try Self.wire())

        #expect(details.optIns == ClientDetails.OptIns(
            email: true, directMessage: true, call: true, wechat: false, line: false
        ))
    }

    @Test("A client without an address, salutation or language has none")
    func absentFieldsStayAbsent() throws {
        // The captured client has none of the three: the fixture as served.
        let details = ClientDetails(wire: try Self.wire())

        #expect(details.address == nil)
        #expect(details.salutation == nil)
        #expect(details.preferredLanguage == nil)
    }

    @Test("An address is kept line by line")
    func addressMaps() throws {
        // The captured client has no address: one is set on the decoded wire.
        var wire = try Self.wire()
        wire.mainAddress = ClientDetailsWire.Address(
            street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
        )

        let details = ClientDetails(wire: wire)

        #expect(details.address == ClientDetails.Address(
            street: "Rua Garrett 50", postalCode: "1200-204", city: "Lisboa", state: nil, country: "PT"
        ))
    }
}
