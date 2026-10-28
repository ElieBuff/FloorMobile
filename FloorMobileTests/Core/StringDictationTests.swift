//
//  StringDictationTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Dictation added to a text")
struct StringDictationTests {

    @Test("What was dictated goes after the text, one space between, never two", arguments: [
        ("", "and no email opt-in", "and no email opt-in"),
        ("spent over 10,000", "and no email opt-in", "spent over 10,000 and no email opt-in"),
        ("spent over 10,000 ", "and no email opt-in", "spent over 10,000 and no email opt-in"),
        ("spent over 10,000\n", "and no email opt-in", "spent over 10,000\nand no email opt-in"),
    ])
    func appendsDictation(text: String, dictation: String, expected: String) {
        var result = text
        result.append(dictation: dictation)

        #expect(result == expected)
    }
}
