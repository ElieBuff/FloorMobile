//
//  SpeechTranscriptionTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The text a transcription builds from the transcriber's results, and when
/// "Done" can hand it back — the parts that run without a microphone. The
/// recording itself is checked on a device.
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

    @Test("A text past the limit is handed back cut at it")
    func textCutAtLimit() {
        var transcript = SpeechTranscription.Transcript()

        transcript.apply(String(repeating: "a", count: 501), isFinal: true)

        #expect(transcript.text(cutAt: 500) == String(repeating: "a", count: 500))
    }

    @Test("A text within the limit is handed back whole")
    func textWithinLimitWhole() {
        var transcript = SpeechTranscription.Transcript()

        transcript.apply("VIC clients", isFinal: true)
        transcript.apply(" on WhatsApp", isFinal: false)

        #expect(transcript.text(cutAt: 500) == "VIC clients on WhatsApp")
    }

    @Test("The limit is reached at its length, not a character before")
    func limitReachedAtLength() {
        var atLimit = SpeechTranscription.Transcript()
        atLimit.apply(String(repeating: "a", count: 500), isFinal: true)
        var below = SpeechTranscription.Transcript()
        below.apply(String(repeating: "a", count: 499), isFinal: true)

        #expect(atLimit.reaches(500))
        #expect(!below.reaches(500))
    }

    @Test("A new transcription starts with no text")
    func startsEmpty() {
        let transcription = SpeechTranscription(maximumLength: 500)

        #expect(transcription.text.isEmpty)
        #expect(transcription.level == 0)
    }

    @Test("Unless the screen says otherwise, it listens 30 seconds at most")
    func listensThirtySecondsByDefault() {
        #expect(SpeechTranscription(maximumLength: 500).maximumDuration == .seconds(30))
        #expect(SpeechTranscription(maximumDuration: .seconds(120), maximumLength: 500).maximumDuration == .seconds(120))
    }

    @Test("Nothing heard, nothing to hand back: \"Done\" waits")
    func newTranscriptionCannotFinish() {
        #expect(!SpeechTranscription(maximumLength: 500).canFinish)
    }

    @Test("Words heard while listening: \"Done\" can hand them back")
    func listeningWithWordsCanFinish() {
        #expect(SpeechTranscription.canFinish(.listening, text: "VIC clients"))
    }

    @Test("While stopping, \"Done\" waits for the last words")
    func finishingCannotFinish() {
        #expect(!SpeechTranscription.canFinish(.finishing, text: "VIC clients"))
    }

    @Test("Stopped on its own, the words kept: \"Done\" still hands them back")
    func finishedWithWordsCanFinish() {
        #expect(SpeechTranscription.canFinish(.finished, text: "VIC clients"))
    }

    @Test("Finishing a transcription that never listened hands back no text and leaves it idle")
    func finishWithoutListening() async {
        let transcription = SpeechTranscription(maximumLength: 500)

        let text = await transcription.finish()

        #expect(text.isEmpty)
        guard case .idle = transcription.state else {
            Issue.record("Expected the transcription to stay idle")
            return
        }
    }

    @Test("Cancelling a transcription that never listened leaves it idle, with no text")
    func cancelWithoutListening() async {
        let transcription = SpeechTranscription(maximumLength: 500)

        await transcription.cancel()

        #expect(transcription.text.isEmpty)
        #expect(transcription.level == 0)
        guard case .idle = transcription.state else {
            Issue.record("Expected the transcription to stay idle")
            return
        }
    }
}
