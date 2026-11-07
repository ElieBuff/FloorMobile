//
//  ClientEditsTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// What the lists the server serves show after an edit, until their next
/// search.
@MainActor
@Suite("Client edits")
struct ClientEditsTests {

    private static let card = ClientItem(id: "1", firstName: "Alice", lastName: "Martinez")

    @Test("A card no edit saved shows as the page holds it")
    func unsavedCardShowsAsReceived() {
        #expect(ClientEdits().current(Self.card) == Self.card)
    }

    @Test("A saved edit shows in place of the page's card, and a later one in place of it")
    func savedEditShows() {
        let edits = ClientEdits()
        var first = Self.card
        first.firstName = "Alicia"
        var second = first
        second.primaryPhone = "+33 6 00 00 00 00"

        edits.record(first)
        #expect(edits.current(Self.card) == first)
        edits.record(second)
        #expect(edits.current(Self.card) == second)
    }

    @Test("An edit shows only for its own client")
    func editIsPerClient() {
        let edits = ClientEdits()
        var edited = Self.card
        edited.firstName = "Alicia"
        let other = ClientItem(id: "2", firstName: "Hélène")

        edits.record(edited)

        #expect(edits.current(other) == other)
    }

    @Test("A new search forgets every edit")
    func removeAllForgets() {
        let edits = ClientEdits()
        var edited = Self.card
        edited.firstName = "Alicia"
        edits.record(edited)

        edits.removeAll()

        #expect(edits.current(Self.card) == Self.card)
    }
}
