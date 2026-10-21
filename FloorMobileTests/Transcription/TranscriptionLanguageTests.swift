//
//  TranscriptionLanguageTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Transcription language")
struct TranscriptionLanguageTests {

    // MARK: - Where a transcription starts

    @Test("The language last picked in the sheet comes before the associate's")
    func lastPickComesFirst() async {
        let language = Self.language(lastPicked: "it_IT", associate: "Fr", device: "en_US")

        #expect(await language.startLocale().identifier == "it_IT")
    }

    @Test("The associate's language comes before the device's")
    func associateComesBeforeDevice() async {
        let language = Self.language(associate: "Fr", device: "en_US")

        #expect(await language.startLocale().identifier == "fr_FR")
    }

    @Test("With no associate's language, the device's")
    func deviceWithoutAssociate() async {
        let language = Self.language(device: "it_IT")

        #expect(await language.startLocale().identifier == "it_IT")
    }

    @Test("A language the transcriber does not know falls back to English")
    func unsupportedFallsBackToEnglish() async {
        let language = Self.language(associate: "Xx", device: "xx_XX")

        #expect(await language.startLocale() == TranscriptionLanguage.fallback)
    }

    // MARK: - Which models are prepared ahead

    @Test("A device in English and an associate in French prepare both")
    func twoLanguagesPrepareTwo() async {
        let language = Self.language(associate: "Fr", device: "en_US")

        #expect(await language.localesToPrepare().map(\.identifier) == ["en_US", "fr_FR"])
    }

    @Test("A device and an associate in French prepare French once")
    func sameLanguagePreparesOnce() async {
        let language = Self.language(associate: "Fr", device: "fr_FR")

        #expect(await language.localesToPrepare().map(\.identifier) == ["fr_FR"])
    }

    @Test("With no associate's language, only the device's is prepared")
    func deviceAloneWithoutAssociate() async {
        let language = Self.language(device: "en_US")

        #expect(await language.localesToPrepare().map(\.identifier) == ["en_US"])
    }

    // MARK: - Helpers

    /// A transcriber that knows French, English and Italian, naming each by
    /// its full locale — as `SpeechTranscriber.supportedLocale(equivalentTo:)`
    /// does — and nothing else.
    private static func language(
        lastPicked: String? = nil,
        associate: String? = nil,
        device: String
    ) -> TranscriptionLanguage {
        TranscriptionLanguage(
            associateLanguage: associate,
            deviceLocale: Locale(identifier: device),
            lastPicked: .inMemory(lastPicked),
            supportedLocale: { locale in
                let known = ["fr": "fr_FR", "en": "en_US", "it": "it_IT"]
                return known[locale.language.languageCode?.identifier ?? ""].map(Locale.init(identifier:))
            }
        )
    }
}
