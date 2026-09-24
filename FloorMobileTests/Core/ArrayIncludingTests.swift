//
//  ArrayIncludingTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// What keeps a `Picker` honest about a value it was never offered: an
/// appointment booked elsewhere keeps its 45 minutes until someone changes
/// them, rather than being rewritten by the first tap.
@Suite("Widening a list of options")
struct ArrayIncludingTests {

    @Test("A value the list already holds does not repeat")
    func offeredValuesAreNotDuplicated() {
        #expect([15, 30, 60].including(30) == [15, 30, 60])
    }

    @Test("A value the list does not hold is appended")
    func unofferedValuesJoinTheList() {
        #expect([15, 30, 60].including(45) == [15, 30, 60, 45])
    }

    @Test("Appended, not sorted — ordering is the caller's business")
    func orderIsLeftToTheCaller() {
        // `EventComposerView` sorts durations after widening and sorts the
        // reminder offsets differently; this helper must not pick for them.
        #expect([15, 60].including(30) == [15, 60, 30])
    }

    @Test("An empty list becomes the one value")
    func emptyListTakesTheValue() {
        #expect([Int]().including(45) == [45])
    }

    @Test("It widens optionals too, including on `nil`")
    func optionalsAreWidened() {
        // The reminder list is `[Int?]` with "none" first, so `nil` is a value
        // like any other and must not be appended twice.
        let offsets: [Int?] = [nil, 5, 15]
        #expect(offsets.including(nil) == offsets)
        #expect(offsets.including(20) == [nil, 5, 15, 20])
    }
}
