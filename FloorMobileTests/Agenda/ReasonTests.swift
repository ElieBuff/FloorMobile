//
//  ReasonTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

@Suite("Reason mapping")
struct ReasonTests {

    @Test("Every known server value maps to its case", arguments: [
        ("BIRTHDAY", Reason.birthday),
        ("BACK_IN_STOCK", Reason.backInStock),
        ("COLLECTION_LAUNCH", Reason.collectionLaunch),
        ("VIP_EVENT", Reason.vipEvent),
        ("FOLLOW_UP", Reason.followUp),
        ("WISHLIST_AVAILABLE", Reason.wishlistAvailable),
        ("OTHER", Reason.other),
    ])
    func mapsKnownValues(raw: String, expected: Reason) {
        #expect(Reason(raw: raw) == expected)
    }

    @Test("An unknown server value falls back to .other")
    func unknownFallsBackToOther() {
        #expect(Reason(raw: "SOME_FUTURE_REASON") == .other)
        #expect(Reason(raw: "") == .other)
    }

    @Test("The seven documented reasons are all covered")
    func coversAllReasons() {
        #expect(Reason.allCases.count == 7)
    }
}
