//
//  BrandClientWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Brand client wire")
struct BrandClientWireTests {

    /// The fixture page, decoded the way `APIClient` decodes it.
    private static func page() throws -> CursorPage<BrandClientWire.Response> {
        try APIClient.makeDecoder().decode(
            CursorPage<BrandClientWire.Response>.self,
            from: try Fixture.data("client_search_page")
        )
    }

    @Test("A search page decodes, cursor and all")
    func pageDecodes() throws {
        let page = try Self.page()

        #expect(page.items.count == 2)
        #expect(page.hasMore)
        #expect(page.nextCursor == "search-cursor-2")
    }

    @Test("A full card maps onto display names, store and associate flattened")
    func fullCardMaps() throws {
        let client = BrandClient(wire: try Self.page().items[0])

        #expect(client.id == "01JBRAND0000000000000000A1")
        #expect(client.displayName == "Nina Larsen")
        #expect(client.segment == "VIC")
        // `store.name` and `SA` on the wire.
        #expect(client.storeName == "Regent Street")
        #expect(client.salesAssociateName == "Elie Buff")
    }

    @Test("A card with nothing but its ids maps to empty fields")
    func sparseCardMaps() throws {
        let client = BrandClient(wire: try Self.page().items[1])

        #expect(client.displayName == nil)
        #expect(client.segment == nil)
        #expect(client.storeName == nil)
        #expect(client.salesAssociateName == nil)
    }
}
