//
//  ClientItemTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Client item")
struct ClientItemTests {

    /// A search fixture page, decoded the way `APIClient` decodes it.
    private static func page(_ fixture: String) throws -> CursorPage<ClientWire.Response> {
        try APIClient.makeDecoder().decode(CursorPage<ClientWire.Response>.self, from: try Fixture.data(fixture))
    }

    // MARK: - From a server card

    @Test("A brand card maps onto names, store and associate, with no way to reach the client")
    func brandCardMaps() throws {
        let item = ClientItem(wire: try Self.page("client_search_page").items[0])

        #expect(item.id == "01JBRAND0000000000000000A1")
        #expect(item.displayName == "Nina Larsen")
        #expect(item.segment == "VIC")
        #expect(item.storeCode == "90917667064")
        #expect(item.storeName == "My Custom Location")
        #expect(item.salesAssociateExternalId == "378970372512460673")
        #expect(item.salesAssociateName == "Elie Buff")
        // The search never sends them for a client of the brand (their profile does).
        #expect(item.primaryEmail == nil)
        #expect(item.primaryPhone == nil)
    }

    @Test("A card of the associate's own clients maps with the email and the phone too")
    func mineCardMaps() throws {
        let page = try Self.page("client_my_clients_page")
        let item = ClientItem(wire: page.items[0])

        #expect(page.nextCursor == "my-clients-cursor-2")
        #expect(item.displayName == "Aliette Martin")
        #expect(item.storeCode == "90917634296")
        #expect(item.storeName == "Shop location")
        #expect(item.salesAssociateExternalId == "seed-sa-001")
        #expect(item.salesAssociateName == "Thomas Torres")
        #expect(item.primaryEmail == "seed.client.375493@example.test")
        #expect(item.primaryPhone == "+33612345678")
    }

    @Test("A card with nothing but its ids maps to empty fields")
    func sparseCardMaps() throws {
        let item = ClientItem(wire: try Self.page("client_search_page").items[1])

        #expect(item.displayName == nil)
        #expect(item.segment == nil)
        #expect(item.storeCode == nil)
        #expect(item.storeName == nil)
        #expect(item.salesAssociateExternalId == nil)
        #expect(item.salesAssociateName == nil)
    }

    // MARK: - From the device

    @Test("A client the device keeps maps onto the same item")
    @MainActor
    func storedClientMaps() throws {
        let container = try ModelContainer(
            for: Client.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let client = Client(
            id: "1", externalId: "seed-client-1", firstName: "Alice", lastName: "Martinez",
            primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78", segment: "VIC",
            storeCode: "90917634296", store: StoreSummary(name: "Shop location", storeCode: "90917634296"),
            salesAssociateExternalId: "378970372512460673",
            salesAssociate: SalesAssociateSummary(firstName: "Elie", lastName: "Buff")
        )
        container.mainContext.insert(client)

        #expect(ClientItem(client: client) == ClientItem(
            id: "1", displayName: "Alice Martinez", segment: "VIC",
            storeCode: "90917634296", storeName: "Shop location",
            salesAssociateExternalId: "378970372512460673", salesAssociateName: "Elie Buff",
            primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
        ))
    }
}
