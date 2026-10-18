//
//  MyClientWireTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("My client wire")
struct MyClientWireTests {

    /// The fixture page, decoded the way `APIClient` decodes it.
    private static func page() throws -> CursorPage<MyClientWire.Response> {
        try APIClient.makeDecoder().decode(
            CursorPage<MyClientWire.Response>.self,
            from: try Fixture.data("client_my_clients_page")
        )
    }

    @Test("A search page decodes, cursor and all")
    func pageDecodes() throws {
        let page = try Self.page()

        #expect(page.items.count == 2)
        #expect(page.hasMore)
        #expect(page.nextCursor == "my-clients-cursor-2")
    }

    @Test("A full card maps onto a display name, with the email and the phone")
    func fullCardMaps() throws {
        let client = MyClient(wire: try Self.page().items[0])

        #expect(client.id == "6d2a1f0e-5b3c-4e7a-9f10-2c4b8e6a0001")
        #expect(client.displayName == "Aliette Martin")
        #expect(client.primaryEmail == "seed.client.375493@example.test")
        #expect(client.primaryPhone == "+33612345678")
    }

    @Test("A card with neither a name nor a way to reach the client maps to empty fields")
    func sparseCardMaps() throws {
        let client = MyClient(wire: try Self.page().items[1])

        #expect(client.displayName == nil)
        #expect(client.primaryEmail == nil)
        #expect(client.primaryPhone == nil)
    }
}
