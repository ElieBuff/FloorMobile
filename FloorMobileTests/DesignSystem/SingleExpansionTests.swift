//
//  SingleExpansionTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

@Suite("Single-open accordion")
struct SingleExpansionTests {

    @Test("Starts fully collapsed")
    func startsCollapsed() {
        let selection = SingleExpansion<String>()
        #expect(selection.openID == nil)
        #expect(!selection.isOpen("a"))
    }

    @Test("Tapping a row opens it")
    func opensOnTap() {
        var selection = SingleExpansion<String>()
        selection.toggle("a")
        #expect(selection.isOpen("a"))
    }

    @Test("Tapping the open row closes it")
    func closesOnSecondTap() {
        var selection = SingleExpansion<String>()
        selection.toggle("a")
        selection.toggle("a")
        #expect(selection.openID == nil)
    }

    @Test("Opening another row closes the previous one")
    func singleOpenAtATime() {
        var selection = SingleExpansion<String>()
        selection.toggle("a")
        selection.toggle("b")
        #expect(selection.isOpen("b"))
        #expect(!selection.isOpen("a"))
    }
}
