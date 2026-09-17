//
//  StringInitialsTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("String initials")
struct StringInitialsTests {

    @Test("Initials are the first letters of the first two words, uppercased", arguments: [
        ("Elie Buff", "EB"),
        ("elie buff", "EB"),
        ("Marie-Charlotte Delestre", "MD"),
        ("Raphaël Van den Berg", "RV"),
        ("Aïcha Moreau", "AM"),
    ])
    func twoWords(name: String, expected: String) {
        #expect(name.initials == expected)
    }

    @Test("A single word yields a single initial", arguments: ["Elie", "elie", "Salomé"])
    func singleWord(name: String) {
        #expect(name.initials == String(name.first!).uppercased())
    }

    @Test("Runs of whitespace and surrounding spaces are ignored", arguments: [
        "  Elie   Buff  ",
        "Elie\tBuff",
        "\nElie Buff\n",
    ])
    func whitespaceIsIgnored(name: String) {
        #expect(name.initials == "EB")
    }

    @Test("An empty or blank name yields an empty string", arguments: ["", "   ", "\n\t"])
    func blankName(name: String) {
        #expect(name.initials == "")
    }

    @Test("An email used as a display name falls back to its first character")
    func emailFallback() {
        // `User.name` falls back to the email when the token carries no name.
        #expect("elie.buff@gmail.com".initials == "E")
    }
}
