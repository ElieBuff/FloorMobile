//
//  ClientSearchOptionsTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client search options")
struct ClientSearchOptionsTests {

    @Test("Nothing picked is the server's default; any one pick is not")
    func isDefault() {
        #expect(ClientSearchOptions().isDefault)
        #expect(!ClientSearchOptions(sortBy: "name").isDefault)
        #expect(!ClientSearchOptions(direction: .desc).isDefault)
        #expect(!ClientSearchOptions(filters: [ClientFilterChoice(ref: "a")]).isDefault)
    }

    // MARK: - Sort

    @Test("Picking a sort takes its value and its stored direction, and leaves the filters")
    func pickTakesValueAndDirection() {
        var options = ClientSearchOptions(filters: [ClientFilterChoice(ref: "a")])

        options.pick(Self.lastPurchase)

        #expect(options.sortBy == "lastPurchase")
        #expect(options.direction == .desc)
        #expect(options.filters == [ClientFilterChoice(ref: "a")])
    }

    @Test("The server's default sort is sent as picked too: which one is the default is the server's call")
    func pickingTheDefaultSendsIt() {
        var options = ClientSearchOptions()

        options.pick(Self.name)

        #expect(options.sortBy == "name")
        #expect(options.direction == .asc)
        #expect(!options.isDefault)
    }

    @Test("While none is picked, the server's default sort is the ticked one")
    func defaultIsPickedWhenNoneIs() {
        let options = ClientSearchOptions()

        #expect(options.isPicked(Self.name))
        #expect(!options.isPicked(Self.lastPurchase))
    }

    @Test("A picked sort is ticked by its value and its direction alike")
    func pickedNeedsValueAndDirection() {
        var options = ClientSearchOptions()
        options.pick(Self.lastPurchase)

        #expect(options.isPicked(Self.lastPurchase))
        #expect(!options.isPicked(Self.name))

        // The same sort the other way round is not the one picked.
        options.direction = .asc
        #expect(!options.isPicked(Self.lastPurchase))
    }

    // MARK: - Helpers

    /// Computed, a fresh one each time: a `@Model` is not `Sendable`, so it
    /// cannot sit in a static stored property.
    private static var name: ClientSort {
        ClientSort(value: "name", labelKey: "client.sort.name", directionRaw: "asc", isDefault: true, rank: 0)
    }
    private static var lastPurchase: ClientSort {
        ClientSort(
            value: "lastPurchase", labelKey: "client.sort.lastPurchase", directionRaw: "desc", isDefault: false, rank: 1
        )
    }
}
