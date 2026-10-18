//
//  ClientWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client wire")
struct ClientWireTests {

    /// A page of a sync fixture, decoded the way `APIClient` decodes it.
    private static func page(_ fixture: String = "client_sync_page1") throws -> CursorPage<ClientWire.Response> {
        try APIClient.makeDecoder().decode(
            CursorPage<ClientWire.Response>.self,
            from: try Fixture.data(fixture)
        )
    }

    @Test("A sync page decodes, cursor and all")
    func pageDecodes() throws {
        let page = try Self.page()

        #expect(page.items.count == 2)
        #expect(page.hasMore)
        #expect(page.nextCursor == "cursor-page-2")
    }

    @Test("A full client maps onto the model, the associate flattened")
    func fullClientMaps() throws {
        let client = Client(wire: try Self.page().items[0])

        #expect(client.id == "0002b7b6-5167-4e0a-88c9-74d7bb83abbd")
        #expect(client.externalId == "seed-client-206362")
        #expect(client.displayName == "Alice Martinez")
        #expect(client.primaryEmail == "seed.client.206362@example.test")
        #expect(client.primaryPhone == nil)
        #expect(client.segment == "One Timer")
        #expect(client.optinEmail && client.optinPhone && !client.optinIM)
        // `SAExternalId` / `SA` on the wire.
        #expect(client.salesAssociateExternalId == "378970372512460673")
        #expect(client.salesAssociate?.displayName == "Elie Buff")
        #expect(client.totalSpent12M == 1250)
        #expect(client.totalSpentLifetime == 4380)
        #expect(client.numTransactions12M == 3)
        #expect(client.lastTransactionAt != nil)
        // A date without fractional seconds decodes too.
        #expect(client.lastInteractionAt != nil)
        #expect(client.preferredChannelRaw == "EMAIL")
        #expect(client.rfmRecency12M == 4)
        #expect(client.searchWords == ["206362", "alice", "client", "martinez", "seed", "seedclient206362"])
        #expect(client.searchPhones.isEmpty)
    }

    @Test("A client with nothing but its ids and flags decodes")
    func sparseClientMaps() throws {
        let client = Client(wire: try Self.page().items[1])

        #expect(client.displayName == nil)
        #expect(client.salesAssociate == nil)
        #expect(client.salesAssociateExternalId == nil)
        #expect(client.preferredChannelRaw == nil)
        #expect(client.rfmRecency12M == nil)
        #expect(client.totalSpentLifetime == 0)
        #expect(client.searchWords.isEmpty)
        #expect(client.searchPhones.isEmpty)
    }

    @Test("A compound name and a phone number decode as the server built them")
    func searchFieldsMap() throws {
        let client = Client(wire: try Self.page("client_sync_page2").items[0])

        #expect(client.searchWords == ["berg", "den", "raphael", "van", "vandenberg"])
        #expect(client.searchPhones == ["33612345678"])
    }

    @Test("The store's id list decodes")
    func storeIDsDecode() throws {
        let store = try APIClient.makeDecoder().decode(
            ClientWire.StoreIDs.self,
            from: try Fixture.data("client_filter_ids")
        )

        #expect(store.storeCode == "90917634296")
        #expect(store.ids.count == 3)
    }
}
