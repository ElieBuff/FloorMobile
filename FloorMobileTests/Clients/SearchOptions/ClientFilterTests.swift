//
//  ClientFilterTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client filter")
struct ClientFilterTests {

    /// `key`'s text in the catalog: what a title must show, whatever its
    /// wording — `seededKeyTranslated` checks it differs from the key.
    private static func translation(of key: String) -> String {
        String(localized: LocalizedStringResource(stringLiteral: key))
    }

    // MARK: - A value's title

    @Test("A generated value shows its label as is, never looked up in the catalog")
    func labelShownAsIs() {
        // A key the catalog translates (`seededKeyTranslated`): looked up, it would change.
        let value = ClientFilterValue(ref: "r1", labelKey: nil, label: "client.filter.tier", parameters: [])

        #expect(value.title == "client.filter.tier")
    }

    @Test("A value with a label key shows the catalog's translation")
    func labelKeyTranslated() {
        let value = ClientFilterValue(ref: "r1", labelKey: "client.filter.value.last3Months", label: nil, parameters: [])

        #expect(value.title == Self.translation(of: "client.filter.value.last3Months"))
    }

    @Test("A value with neither a label nor a key shows its ref, never a blank row")
    func neitherShowsRef() {
        let value = ClientFilterValue(ref: "r1", labelKey: nil, label: nil, parameters: [])

        #expect(value.title == "r1")
    }

    // MARK: - A filter's title

    @Test("A filter's title is its key's translation")
    func filterTitleTranslated() {
        let filter = ClientFilter(
            id: "f", titleKey: "client.filter.lastPurchase", selectionRaw: "SINGLE", rank: 0, values: []
        )

        #expect(String(localized: filter.title) == Self.translation(of: "client.filter.lastPurchase"))
    }

    // MARK: - Typed views

    @Test("SINGLE and MULTIPLE read as their selection; a value this app does not know, as none", arguments: zip(
        ["SINGLE", "MULTIPLE", "SOMETIMES"], [ClientFilter.Selection.single, .multiple, nil]
    ))
    func selectionReadsItsRaw(raw: String, selection: ClientFilter.Selection?) {
        let filter = ClientFilter(id: "f", titleKey: "k", selectionRaw: raw, rank: 0, values: [])

        #expect(filter.selection == selection)
    }

    @Test("A parameter typed date reads as a day; any other type as a kind this app does not draw")
    func parameterKind() {
        #expect(ClientFilterValue.Parameter(name: "since", typeRaw: "date").kind == .date)
        #expect(ClientFilterValue.Parameter(name: "amount", typeRaw: "int").kind == nil)
    }

    @Test("A value whose one parameter is a date asks for a day")
    func oneDateAsksForADay() {
        let since = ClientFilterValue.Parameter(name: "since", typeRaw: "date")
        let value = ClientFilterValue(ref: "r1", labelKey: nil, label: nil, parameters: [since])

        #expect(value.dateParameter == since)
    }

    @Test(
        "A value asks for no day without a parameter, with two dates, or with a kind this app does not draw",
        arguments: [
            [],
            [
                ClientFilterValue.Parameter(name: "from", typeRaw: "date"),
                ClientFilterValue.Parameter(name: "to", typeRaw: "date"),
            ],
            [ClientFilterValue.Parameter(name: "amount", typeRaw: "int")],
        ] as [[ClientFilterValue.Parameter]]
    )
    func noDayOtherwise(parameters: [ClientFilterValue.Parameter]) {
        let value = ClientFilterValue(ref: "r1", labelKey: nil, label: nil, parameters: parameters)

        #expect(value.dateParameter == nil)
    }

    // MARK: - The catalog

    // The keys FloorPlatform's dev seed writes (`floor/console/api/src/scripts/seed-client-filters.ts`),
    // mirrored by hand: one the catalog misses shows on screen as the key itself.
    @Test("Every key the dev seed writes is translated in the catalog", arguments: [
        "client.filter.tier", "client.filter.created", "client.filter.lastPurchase",
        "client.filter.value.last3Months", "client.filter.value.last6Months",
        "client.filter.value.last12Months", "client.filter.value.since",
    ])
    func seededKeyTranslated(key: String) {
        #expect(Self.translation(of: key) != key)
    }
}
