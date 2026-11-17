//
//  ClientTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Client")
@MainActor
struct ClientTests {

    // MARK: - Page

    /// An in-memory store holding `clients`, inserted in the order given.
    private func store(_ clients: [Client]) throws -> ModelContainer {
        let container = try ModelContainer(
            for: Client.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        clients.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        return container
    }

    /// `count` clients, "Client 0" to "Client n" by last name, inserted last first.
    private func numbered(_ count: Int) -> [Client] {
        (0..<count).reversed().map { Client(id: "c\($0)", externalId: "\($0)", lastName: "Client \($0)") }
    }

    @Test("Clients come by last name, then first name")
    func byLastThenFirstName() throws {
        let container = try store([
            Client(id: "zoe", externalId: "1", firstName: "Zoé", lastName: "Martin"),
            Client(id: "paul", externalId: "2", firstName: "Paul", lastName: "Dubois"),
            Client(id: "anne", externalId: "3", firstName: "Anne", lastName: "Martin"),
        ])

        let page = try Client.page(after: nil, size: 10, in: container.mainContext)

        #expect(page.clients.map(\.id) == ["paul", "anne", "zoe"])
        #expect(page.next == nil)
    }

    @Test("Each full page says where the next starts, and the last says there is none")
    func pagesFollowOneAnother() throws {
        let container = try store(numbered(5))
        let context = container.mainContext

        let first = try Client.page(after: nil, size: 2, in: context)
        let second = try Client.page(after: first.next, size: 2, in: context)
        let last = try Client.page(after: second.next, size: 2, in: context)

        #expect(first.clients.map(\.id) == ["c0", "c1"])
        #expect(first.next == "2")
        #expect(second.clients.map(\.id) == ["c2", "c3"])
        #expect(second.next == "4")
        #expect(last.clients.map(\.id) == ["c4"])
        #expect(last.next == nil)
    }

    @Test("Clients of the same name come by id, each once across the pages")
    func sameNameByID() throws {
        let container = try store(["c3", "c1", "c2"].map {
            Client(id: $0, externalId: $0, firstName: "Anne", lastName: "Martin")
        })
        let context = container.mainContext

        let first = try Client.page(after: nil, size: 2, in: context)
        let last = try Client.page(after: first.next, size: 2, in: context)

        #expect(first.clients.map(\.id) == ["c1", "c2"])
        #expect(last.clients.map(\.id) == ["c3"])
    }

    @Test("A store that ends on a full page gives an empty last page")
    func fullLastPage() throws {
        let container = try store(numbered(4))

        let last = try Client.page(after: "4", size: 2, in: container.mainContext)

        #expect(last.clients.isEmpty)
        #expect(last.next == nil)
    }

    // MARK: - Edit

    @Test("An edit takes the name, the email, the phone, the address and the consents, and leaves the rest")
    func applyTakesEditableFields() {
        let client = Client(
            id: "alice", externalId: "1", firstName: "Alice", lastName: "Martinez",
            primaryEmail: "alice@example.com", segment: "VIC", salesAssociateExternalId: "sa-1",
            searchWords: ["alice", "martinez"], salutation: "misses"
        )
        let address = ClientItem.Address(street: "12 Rue Royale", postalCode: "75008", city: "Paris", state: nil, country: "FR")
        let optIns = ClientItem.OptIns(email: false, directMessage: true, call: false, wechat: false, line: false)

        client.apply(ClientItem(
            id: "alice", firstName: "Alicia", lastName: "Martin", segment: "Gold",
            primaryEmail: nil, primaryPhone: "+33 6 00 00 00 00", salutation: "miss",
            address: address, optIns: optIns
        ))

        #expect(client.firstName == "Alicia")
        #expect(client.lastName == "Martin")
        #expect(client.primaryEmail == nil)
        #expect(client.primaryPhone == "+33 6 00 00 00 00")
        #expect(client.address == address)
        #expect(client.optIns == optIns)
        // Not editable: as the server last sent them.
        #expect(client.segment == "VIC")
        #expect(client.salutation == "misses")
        #expect(client.salesAssociateExternalId == "sa-1")
        #expect(client.searchWords == ["alice", "martinez"])
    }
}
