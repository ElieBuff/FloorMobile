//
//  PillActionTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

/// What a touch on a pill's body does, row by row of the table its doc gives.
@Suite("Pill action")
struct PillActionTests {

    @Test("A pill neither choosable nor removable does nothing")
    func inertDoesNothing() {
        #expect(PillAction.body(isSelected: nil, isRemovable: false) == .none)
    }

    @Test("A choosable pill toggles to the other value", arguments: [true, false])
    func choosableToggles(isSelected: Bool) {
        #expect(PillAction.body(isSelected: isSelected, isRemovable: false) == .toggle(to: !isSelected))
    }

    @Test("A removable pill that is not choosable is removed by a touch anywhere")
    func removableRemoves() {
        #expect(PillAction.body(isSelected: nil, isRemovable: true) == .remove)
    }

    @Test("A choosable and removable pill toggles from its body — its cross removes", arguments: [true, false])
    func choosableAndRemovableToggles(isSelected: Bool) {
        #expect(PillAction.body(isSelected: isSelected, isRemovable: true) == .toggle(to: !isSelected))
    }
}
