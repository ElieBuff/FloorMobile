//
//  ClientSummaryTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// `displayName` is what every task row, every appointment row and both detail
/// screens put in front of the advisor, and the API fills neither name
/// reliably. What it returns for a half-filled client is not a detail.
@Suite("Client summary")
struct ClientSummaryTests {

    @Test("Both names join with a single space")
    func bothNamesJoin() {
        let client = ClientSummary(firstName: "Raphaël", lastName: "Van den Berg")
        #expect(client.displayName == "Raphaël Van den Berg")
    }

    /// Typed explicitly: left to inference, the two rows disagree on whether
    /// `first` is `String` or `String?`.
    private static let halfNames: [(first: String?, last: String?, expected: String)] = [
        ("Salomé", nil, "Salomé"),
        (nil, "Kaliny", "Kaliny"),
    ]

    @Test("One name alone is a name", arguments: halfNames)
    func oneNameIsEnough(first: String?, last: String?, expected: String) {
        #expect(ClientSummary(firstName: first, lastName: last).displayName == expected)
    }

    @Test("No name at all is `nil`, not an empty string")
    func noNameIsNil() {
        // `nil` so a caller can fall back — an empty string would draw a row
        // with a blank where the client goes.
        #expect(ClientSummary().displayName == nil)
    }

    @Test("A name that is only whitespace counts as no name", arguments: ["", " ", "   "])
    func blankNamesAreNoName(blank: String) {
        #expect(ClientSummary(firstName: blank, lastName: blank).displayName == nil)
    }

    @Test("Surrounding whitespace is trimmed rather than joined")
    func surroundingWhitespaceIsTrimmed() {
        let client = ClientSummary(firstName: "  Inès ", lastName: " Haddad  ")
        #expect(client.displayName == "Inès Haddad")
    }

    @Test("A blank first name does not leave a leading space on the last")
    func blankFirstNameLeavesNoGap() {
        #expect(ClientSummary(firstName: "  ", lastName: "Kaliny").displayName == "Kaliny")
    }
}
