//
//  EventStatusTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("EventStatus")
struct EventStatusTests {

    @Test("Every status the API sends round-trips through its raw value", arguments: EventStatus.allCases)
    func rawValuesMap(status: EventStatus) {
        #expect(EventStatus(raw: status.rawValue) == status)
    }

    @Test("The four values the API actually sends are covered")
    func apiVocabulary() {
        #expect(EventStatus(raw: "PLANNED") == .planned)
        #expect(EventStatus(raw: "CONFIRMED") == .confirmed)
        #expect(EventStatus(raw: "COMPLETED") == .completed)
        #expect(EventStatus(raw: "CANCELLED") == .cancelled)
    }

    @Test("An unknown status falls back instead of breaking decoding", arguments: [
        "RESCHEDULED", "", "NO_SHOW", "planned",
    ])
    func unknownFallsBack(raw: String) {
        // Lower case lands here too: the API is upper case and the mapping is
        // exact, the same way `Reason` treats its own raw values. If that ever
        // stops holding, this is the test that says so.
        #expect(EventStatus(raw: raw) == .other)
    }
}
