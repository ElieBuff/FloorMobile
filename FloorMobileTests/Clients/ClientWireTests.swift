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

    @Test("A full client maps onto the model, the store and the associate kept as snapshots")
    func fullClientMaps() throws {
        let client = Client(wire: try Self.page().items[0])

        #expect(client.id == "0002b7b6-5167-4e0a-88c9-74d7bb83abbd")
        #expect(client.externalId == "seed-client-206362")
        #expect(client.displayName == "Alice Martinez")
        #expect(client.primaryEmail == "seed.client.206362@example.test")
        #expect(client.primaryPhone == nil)
        #expect(client.segment == "One Timer")
        #expect(client.storeCode == "90917634296")
        #expect(client.store?.name == "Shop location")
        // `SAExternalId` / `SA` on the wire; the associate comes with its internal id too.
        #expect(client.salesAssociateExternalId == "378970372512460673")
        #expect(client.salesAssociate?.id == "01KTRSFERMNXK5FGSQW11M1478")
        #expect(client.salesAssociate?.displayName == "Elie Buff")
        #expect(client.searchWords == ["206362", "alice", "client", "martinez", "seed", "seedclient206362"])
        #expect(client.searchPhones.isEmpty)
    }

    @Test("A client with nothing but its ids and its store decodes")
    func sparseClientMaps() throws {
        let client = Client(wire: try Self.page().items[1])

        #expect(client.displayName == nil)
        #expect(client.primaryEmail == nil)
        #expect(client.segment == nil)
        #expect(client.salesAssociate == nil)
        #expect(client.salesAssociateExternalId == nil)
        #expect(client.searchWords.isEmpty)
        #expect(client.searchPhones.isEmpty)
    }

    @Test("A client from a BFF that does not send the store yet decodes, its store left empty")
    func clientWithoutStoreDecodes() throws {
        // client_sync_page2.json is the sync as the BFF served it before the card: no store, the fields it no
        // longer sends still there — decoding ignores them.
        let client = Client(wire: try Self.page("client_sync_page2").items[0])

        #expect(client.storeCode == "90917634296")
        #expect(client.store == nil)
        #expect(client.salesAssociate?.displayName == "Elie Buff")
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
