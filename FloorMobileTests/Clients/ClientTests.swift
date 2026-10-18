//
//  ClientTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("Client search")
@MainActor
struct ClientTests {

    /// The ids of the clients `Client.matching(query)` keeps, out of a store
    /// holding Alice, Hélène and a client with nothing on file.
    private func matches(_ query: String) throws -> Set<String> {
        let container = try ModelContainer(
            for: Client.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(Client(
            id: "alice", externalId: "1", firstName: "Alice", lastName: "Martinez",
            primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
        ))
        context.insert(Client(id: "helene", externalId: "2", firstName: "Hélène", lastName: "Dubois"))
        context.insert(Client(id: "empty", externalId: "3"))
        try context.save()

        let found = try context.fetch(FetchDescriptor(predicate: Client.matching(query)))
        return Set(found.map(\.id))
    }

    @Test("A blank query keeps everyone", arguments: ["", "   "])
    func blankQueryKeepsEveryone(query: String) throws {
        #expect(try matches(query) == ["alice", "helene", "empty"])
    }

    @Test(
        "The query is found in a name, the email or the phone, case aside",
        arguments: ["mart", "ALICE", "example.com", "6 12", "  alice  "]
    )
    func findsAcrossFieldsCaseAside(query: String) throws {
        #expect(try matches(query) == ["alice"])
    }

    @Test("Accents aside too", arguments: ["helene", "HÉLÈNE", "dubois"])
    func accentsAside(query: String) throws {
        #expect(try matches(query) == ["helene"])
    }

    @Test(
        "Still a plain 'contains': no spacing in the phone, no full-name match",
        arguments: ["bob", "612", "alice martinez"]
    )
    func plainContains(query: String) throws {
        #expect(try matches(query).isEmpty)
    }
}
