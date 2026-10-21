//
//  SpeechTranscriptionTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The text a transcription builds from the transcriber's results — the part
/// that runs without a microphone. The recording itself is checked on a
/// device.
@Suite("Speech transcription")
@MainActor
struct SpeechTranscriptionTests {

    @Test("A volatile result is replaced by the next one")
    func volatileIsReplaced() {
        var transcript = SpeechTranscription.Transcript()

        transcript.apply("Bonjour", isFinal: false)
        transcript.apply("Bonjour Mme", isFinal: false)

        #expect(transcript.text == "Bonjour Mme")
        #expect(transcript.finalized.isEmpty)
    }

    @Test("A final result is kept, and the volatile tail starts over after it")
    func finalIsAppended() {
        var transcript = SpeechTranscription.Transcript()

        transcript.apply("Bonjour Mme Martin", isFinal: false)
        transcript.apply("Bonjour Mme Martin.", isFinal: true)
        transcript.apply(" Elle cherche", isFinal: false)

        #expect(transcript.finalized == "Bonjour Mme Martin.")
        #expect(transcript.volatile == " Elle cherche")
        #expect(transcript.text == "Bonjour Mme Martin. Elle cherche")
    }

    @Test("Final pieces follow one another, and the text comes back trimmed")
    func finalsChainAndTrim() {
        var transcript = SpeechTranscription.Transcript()

        transcript.apply(" Rappeler demain.", isFinal: true)
        transcript.apply(" Taille 38. ", isFinal: true)

        #expect(transcript.text == "Rappeler demain. Taille 38.")
    }

    @Test("A new transcription starts with no text")
    func startsEmpty() {
        let transcription = SpeechTranscription()

        #expect(transcription.text.isEmpty)
        #expect(transcription.levels.count == SpeechTranscription.levelCount)
    }
}
