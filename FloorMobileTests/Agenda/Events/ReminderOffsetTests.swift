//
//  ReminderOffsetTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Reminder offset")
struct ReminderOffsetTests {

    private static let start = Date(timeIntervalSince1970: 1_788_000_000)

    private static func before(_ minutes: Double) -> Date {
        start.addingTimeInterval(-minutes * 60)
    }

    // MARK: - Recovering the offset

    @Test("An instant becomes the offset the advisor chose", arguments: [5, 15, 30, 60])
    func instantBecomesOffset(offset: Int) {
        #expect(
            ReminderOffset.minutes(from: Self.before(Double(offset)), before: Self.start) == offset
        )
    }

    @Test("Seconds on either instant are rounded away, not truncated")
    func secondsAreRounded() {
        // 29 min 40 s before the start is a half-hour reminder whose instants
        // each carry seconds — "29 min before" would be an artefact on screen.
        #expect(ReminderOffset.minutes(from: Self.before(29.67), before: Self.start) == 30)
    }

    @Test("No reminder, no offset")
    func noReminderMeansNoOffset() {
        #expect(ReminderOffset.minutes(from: nil, before: Self.start) == nil)
    }

    @Test("A reminder at or after the start is no offset anyone chose")
    func nonPositiveOffsetsAreDropped() {
        #expect(ReminderOffset.minutes(from: Self.start, before: Self.start) == nil)
        #expect(ReminderOffset.minutes(from: Self.before(-10), before: Self.start) == nil)
    }

    // MARK: - The vocabulary

    @Test("`none` leads the list, and nothing fires more than an hour early")
    func selectableStaysOnTheShopFloor() {
        #expect(ReminderOffset.selectable.first == .some(nil))
        #expect(ReminderOffset.selectable.compactMap { $0 }.allSatisfy { $0 <= 60 })
    }

    /// The wording is the locale's; what the test pins is that every offer has
    /// a label, and that "no reminder" does not read as a duration.
    @Test("Every offer the form makes reads as something")
    func everyOfferHasALabel() {
        for offset in ReminderOffset.selectable {
            #expect(!ReminderOffset.label(offset).isEmpty)
        }
        #expect(ReminderOffset.label(nil) != ReminderOffset.label(30))
    }
}
