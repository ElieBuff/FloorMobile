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

    // MARK: - Filters

    @Test("Ticking a value of a multiple filter keeps its other values ticked")
    func multipleKeepsOthers() {
        let tier = Self.tier
        var options = ClientSearchOptions()

        options.pick(tier.values[0], of: tier)
        options.pick(tier.values[1], of: tier)

        #expect(options.filters.map(\.ref) == ["tier-VIC", "tier-VIP"])
    }

    @Test("Ticking a value of a single filter lets go of the one it had, not of another filter's")
    func singleLetsGoOfItsOwnOnly() {
        let tier = Self.tier
        let created = Self.created
        var options = ClientSearchOptions()
        options.pick(tier.values[0], of: tier)
        options.pick(created.values[0], of: created)

        options.pick(created.values[1], of: created)

        #expect(options.filters.map(\.ref) == ["tier-VIC", "created-last6Months"])
    }

    @Test("A filter whose selection this app does not know ticks like a multiple one, as the server reads it")
    func unknownSelectionTicksLikeMultiple() {
        let filter = ClientFilter(id: "f", titleKey: "k", selectionRaw: "SOMETIMES", rank: 0, values: [
            ClientFilterValue(ref: "a", labelKey: nil, label: "A", parameters: []),
            ClientFilterValue(ref: "b", labelKey: nil, label: "B", parameters: []),
        ])
        var options = ClientSearchOptions()

        options.pick(filter.values[0], of: filter)
        options.pick(filter.values[1], of: filter)

        #expect(options.filters.map(\.ref) == ["a", "b"])
    }

    @Test("Unticking lets go of that value only")
    func unpickLetsGoOfThatValue() {
        let tier = Self.tier
        var options = ClientSearchOptions()
        options.pick(tier.values[0], of: tier)
        options.pick(tier.values[1], of: tier)

        options.unpick(tier.values[0])

        #expect(!options.isPicked(tier.values[0]))
        #expect(options.isPicked(tier.values[1]))
        #expect(options.filters.map(\.ref) == ["tier-VIP"])
    }

    @Test("Ticking a value again takes its new parameters, never a second entry")
    func pickAgainReplacesParameters() {
        let created = Self.created
        let since = created.values[2]
        var options = ClientSearchOptions()

        options.pick(since, of: created, parameters: ["since": "2026-07-01"])
        options.pick(since, of: created, parameters: ["since": "2026-08-15"])

        #expect(options.filters == [ClientFilterChoice(ref: "created-since", parameters: ["since": "2026-08-15"])])
    }

    @Test("The day picked for a value is read back from its parameter; none for a value not picked or asking for none")
    func dayPickedForReadsTheParameter() throws {
        let created = Self.created
        let since = created.values[2]
        var options = ClientSearchOptions()
        #expect(options.day(pickedFor: since) == nil)

        options.pick(since, of: created, parameters: ["since": "2026-07-01"])

        let day = try #require(options.day(pickedFor: since))
        #expect(day.calendarDay() == "2026-07-01")
        #expect(options.day(pickedFor: created.values[0]) == nil)
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

    /// Two segments, any number of them picked.
    private static var tier: ClientFilter {
        ClientFilter(id: "tier", titleKey: "client.filter.tier", selectionRaw: "MULTIPLE", rank: 0, values: [
            ClientFilterValue(ref: "tier-VIC", labelKey: nil, label: "VIC", parameters: []),
            ClientFilterValue(ref: "tier-VIP", labelKey: nil, label: "VIP", parameters: []),
        ])
    }
    /// One value at a time: two windows, then "Since a date".
    private static var created: ClientFilter {
        ClientFilter(id: "created", titleKey: "client.filter.created", selectionRaw: "SINGLE", rank: 1, values: [
            ClientFilterValue(
                ref: "created-last3Months", labelKey: "client.filter.value.last3Months", label: nil, parameters: []
            ),
            ClientFilterValue(
                ref: "created-last6Months", labelKey: "client.filter.value.last6Months", label: nil, parameters: []
            ),
            ClientFilterValue(
                ref: "created-since", labelKey: "client.filter.value.since", label: nil,
                parameters: [ClientFilterValue.Parameter(name: "since", typeRaw: "date")]
            ),
        ])
    }
}
