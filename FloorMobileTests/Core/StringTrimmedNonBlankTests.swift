//
//  StringTrimmedNonBlankTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A field typed blank is a field not filled in: never an empty string to
/// send.
@Suite("String trimmed non-blank")
struct StringTrimmedNonBlankTests {

    @Test("Surrounding spaces and line breaks go, the text in between stays")
    func trimsTheEdges() {
        #expect("  Alice Martinez \n".trimmedNonBlank == "Alice Martinez")
    }

    @Test("Nothing left is nil", arguments: ["", "   ", "\n\t "])
    func blankIsNil(text: String) {
        #expect(text.trimmedNonBlank == nil)
    }

    @Test("Through optional chaining, a missing value stays nil")
    func optionalChaining() {
        let missing: String? = nil

        #expect(missing?.trimmedNonBlank == nil)
    }
}
