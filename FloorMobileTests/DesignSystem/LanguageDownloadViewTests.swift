//
//  LanguageDownloadViewTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// How far a language download is, as the line under the ring and VoiceOver
/// say it: the percentage alone, iOS giving no sizes.
@Suite("Language download view")
@MainActor
struct LanguageDownloadViewTests {

    private static let english = Locale(identifier: "en_US")

    @Test("The percentage, rounded to the unit", arguments: [
        (0.0, "0%"), (0.38, "38%"), (0.384, "38%"), (0.386, "39%"), (1.0, "100%"),
    ])
    func percentage(fraction: Double, expected: String) {
        #expect(LanguageDownloadView.percentage(fraction, locale: Self.english) == expected)
    }
}
