//
//  MeetingTypeTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The open-set rules `Reason`, `EventStatus` and `TaskStatus` are already held
/// to, applied to the last agenda enum without a suite of its own.
@Suite("Meeting type")
struct MeetingTypeTests {

    @Test("Each value the server publishes maps to itself", arguments: MeetingType.allCases)
    func rawValuesRoundTrip(type: MeetingType) {
        #expect(MeetingType(raw: type.rawValue) == type)
    }

    @Test("A value this build has never heard of lands on `other` rather than failing")
    func unknownValuesLandOnOther() {
        #expect(MeetingType(raw: "PHONE_CALL") == .other)
        #expect(MeetingType(raw: "") == .other)
    }

    @Test("`other` is never offered — it is where unknown values land, not a choice")
    func otherIsNotSelectable() {
        #expect(!MeetingType.selectable.contains(.other))
        #expect(MeetingType.selectable == [.inPerson, .videoCall])
    }

    @Test("Every value reads as something, including the one nobody picks")
    func everyValueHasALabel() {
        for type in MeetingType.allCases {
            #expect(!type.displayLabel.isEmpty)
        }
        // Distinct labels: a control that shows two identical rows is a control
        // whose choice cannot be read back.
        let labels = MeetingType.allCases.map(\.displayLabel)
        #expect(Set(labels).count == labels.count)
    }
}
