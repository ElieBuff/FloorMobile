//
//  LocaleDisplayNameTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A language's name, as a menu lists it and as a title says it, read in a
/// given language.
@Suite("Locale display name")
struct LocaleDisplayNameTests {

    private static let english = Locale(identifier: "en_US")

    @Test("A language and its region, as a menu lists it")
    func languageAndRegion() {
        #expect(Locale(identifier: "fr_FR").displayName(in: Self.english) == "French (France)")
        #expect(Locale(identifier: "en_GB").displayName(in: Self.english) == "English (United Kingdom)")
    }

    @Test("The language alone, with or without its region")
    func languageAlone() {
        #expect(Locale(identifier: "fr_FR").languageName(in: Self.english) == "French")
        #expect(Locale(identifier: "fr").languageName(in: Self.english) == "French")
    }

    @Test("A language the system does not name reads as its identifier")
    func unknownReadsAsIdentifier() {
        #expect(Locale(identifier: "zz_ZZ").displayName(in: Self.english) == "zz_ZZ")
        #expect(Locale(identifier: "zz").languageName(in: Self.english) == "zz")
    }
}
