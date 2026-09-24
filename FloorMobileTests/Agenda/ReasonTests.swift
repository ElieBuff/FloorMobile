//
//  ReasonTests.swift
//  FloorMobileTests
//

import Testing
import UIKit
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

    /// `Reason` looks its assets up by name, built from the raw server value,
    /// so nothing but this test notices a set that was renamed or never added:
    /// the app would simply draw a blank badge.
    @Test("Every reason resolves its icon and its two colors", arguments: Reason.allCases)
    func resolvesItsAssets(reason: Reason) {
        #expect(UIImage(named: "Reason/Icons/\(reason.rawValue)") != nil)
        #expect(UIColor(named: "Reason/Fill/\(reason.rawValue)") != nil)
        #expect(UIColor(named: "Reason/Tint/\(reason.rawValue)") != nil)
    }
}
