//
//  SpeechTranscription.swift
//  FloorMobile
//

import AVFoundation
import Foundation
import Observation
import Speech
import os

/// One voice-to-text transcription, from the microphone, on the device: what
/// `TranscriptionView` starts and shows, and the screen holding it stops.
///
/// It owns the recording the way `AppSession` owns the sign-in — the
/// microphone (`AudioFeed`), the analyzer and its results — and exposes what
/// a view reads: the state, the text as it is heard, the voice's level. Not a
/// view model: no view logic lives here.
///
/// `SpeechAnalyzer` with a `SpeechTranscriber` (iOS 26): on the device, with
/// a model iOS downloads per language and shares between apps. The model must
/// be on the device before `start`: `LanguageDownload` brings it.
@Observable
final class SpeechTranscription {

    enum State {
        /// Not listening yet: the microphone permission, the analyzer setting
        /// up — or nothing asked.
        case idle
        case listening
        /// Stopped listening, the last words being finalized.
        case finishing
        /// Done: `text` is final.
        case finished
        case failed(Failure)
    }

    enum Failure: Equatable {
        /// The associate refused the microphone: only Settings can undo it.
        case microphoneDenied
        /// This device cannot transcribe.
        case unavailable
        /// Anything else, with its message.
        case other(String)
    }

    /// How long it listens at most, then stops on its own, the words kept: 30 s
    /// unless the screen says otherwise — a few sentences, about 75 words
    /// (decision of 16/11).
    let maximumDuration: Duration
    /// The longest text it hands back, in characters, chosen by the screen for
    /// what the text goes to — 500 for a filter's sentence, the server's
    /// limit. Listening stops on its own once the words reach it, kept.
    let maximumLength: Int

    private(set) var state: State = .idle
    private(set) var transcript = Transcript()
    /// The voice's level, 0…1, the last the microphone measured — what the
    /// rings of `ListeningPebble` follow. 0 while not listening.
    private(set) var level: Float = 0

    private var analyzer: SpeechAnalyzer?
    private var feed: AudioFeed?
    private var inputs: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var guardTask: Task<Void, Never>?

    init(maximumDuration: Duration = .seconds(30), maximumLength: Int) {
        self.maximumDuration = maximumDuration
        self.maximumLength = maximumLength
    }

    /// The text so far, final words and words still being decided alike, cut
    /// at `maximumLength`.
    var text: String { transcript.text(cutAt: maximumLength) }

    /// Whether a screen's "Done" can hand the text back (`finish()`): words
    /// heard, and not on their way to their final form — a second "Done"
    /// while stopping would hand the text back before the last words. True
    /// as well once listening stopped on its own (`.finished`: past
    /// `maximumDuration`, the text reaching `maximumLength`, a call, the app
    /// leaving the screen), which kept the words.
    var canFinish: Bool {
        Self.canFinish(state, text: text)
    }

    /// `canFinish` for a given state and text: apart, so the rule is tested
    /// without a microphone.
    static func canFinish(_ state: State, text: String) -> Bool {
        if case .finishing = state { return false }
        return !text.isEmpty
    }

    // MARK: - Starting

    /// Starts listening in `locale`, after the microphone permission; its
    /// model must be on the device (`LanguageDownload`). A transcription
    /// already running is dropped first, its words with it.
    ///
    /// A task cancelled while it waits — "Try again", the screen gone — stops
    /// at its next step and writes nothing: whoever cancelled it owns the
    /// transcription now.
    func start(in locale: Locale) async {
        await cancel()
        guard !Task.isCancelled else { return }

        guard SpeechTranscriber.isAvailable else {
            state = .failed(.unavailable)
            return
        }
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard !Task.isCancelled else { return }
        guard allowed else {
            state = .failed(.microphoneDenied)
            return
        }

        do {
            guard try await listen(in: locale) else { return }
            state = .listening
            watch()
        } catch {
            guard !Task.isCancelled else { return }
            AppLog.ui.error("Transcription failed to start: \(error.localizedDescription, privacy: .public)")
            tearDown()
            state = .failed(.other(error.localizedDescription))
        }
    }

    /// Wires the microphone to the analyzer, and the analyzer's results to
    /// the transcript. What it sets up stays its own until its last wait is
    /// over: the task cancelled by then, it undoes it and returns `false`;
    /// otherwise it keeps it, opens the microphone and returns `true`.
    private func listen(in locale: Locale) async throws -> Bool {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AudioFeed.Failure.unsupportedFormat
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let feed = try AudioFeed(format: format) { input in
            continuation.yield(input)
        } onLevel: { [weak self] level in
            Task { @MainActor in self?.level = level }
        }

        let results = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.transcript.apply(String(result.text.characters), isFinal: result.isFinal)
                    // Long enough: it stops on its own, as past
                    // `maximumDuration` — not awaited, `finish()` waiting for
                    // this very task to end.
                    if let self, transcript.reaches(maximumLength) {
                        Task { await self.finish() }
                    }
                }
            } catch {
                AppLog.ui.error("Transcription results ended: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            results.cancel()
            continuation.finish()
            throw error
        }
        guard !Task.isCancelled else {
            results.cancel()
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            return false
        }

        self.analyzer = analyzer
        self.feed = feed
        inputs = continuation
        resultsTask = results
        try feed.start()
        return true
    }

    /// Stops on its own after `maximumDuration`, or when a call or another app
    /// takes the microphone — the words heard so far are kept. The text
    /// reaching `maximumLength` stops it too, from the results (`listen`).
    private func watch() {
        let maximumDuration = maximumDuration
        guardTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    try? await Task.sleep(for: maximumDuration)
                }
                group.addTask {
                    let interruptions = NotificationCenter.default.notifications(
                        named: AVAudioSession.interruptionNotification
                    )
                    for await _ in interruptions { return }
                }
                await group.next()
                group.cancelAll()
            }
            guard !Task.isCancelled else { return }
            await self?.finish()
        }
    }

    // MARK: - Stopping

    /// Stops listening, waits for the last words, and hands back the final
    /// text — `text` as it stands when it was not listening. A stop nobody
    /// asked for (the time limit, the length reached, a call, the app leaving
    /// the screen) ignores what it hands back: the words stay in `text`, for
    /// the screen's "Done".
    @discardableResult
    func finish() async -> String {
        guard case .listening = state else { return text }
        state = .finishing
        feed?.stop()
        inputs?.finish()
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            AppLog.ui.error("Transcription did not finalize: \(error.localizedDescription, privacy: .public)")
        }
        await resultsTask?.value
        tearDown()
        state = .finished
        return text
    }

    /// Stops at once and drops what was heard. Everything is written before
    /// its one wait, so a start that comes meanwhile finds it clear; the
    /// parts it took off are stopped after.
    func cancel() async {
        let (feed, inputs, analyzer, results) = (self.feed, self.inputs, self.analyzer, resultsTask)
        tearDown()
        transcript = Transcript()
        state = .idle
        results?.cancel()
        feed?.stop()
        inputs?.finish()
        await analyzer?.cancelAndFinishNow()
    }

    private func tearDown() {
        level = 0
        guardTask?.cancel()
        guardTask = nil
        resultsTask = nil
        analyzer = nil
        feed = nil
        inputs = nil
    }
}

// MARK: - Transcript

extension SpeechTranscription {
    /// The text heard so far, as the transcriber reports it: final pieces,
    /// appended once and never changed, and a volatile tail, replaced at every
    /// result until it is finalized in turn.
    struct Transcript: Equatable {
        private(set) var finalized = ""
        private(set) var volatile = ""

        mutating func apply(_ text: String, isFinal: Bool) {
            if isFinal {
                finalized += text
                volatile = ""
            } else {
                volatile = text
            }
        }

        /// What the associate gets back: the whole text, trimmed.
        var text: String {
            (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// `text`, cut at `length` characters: what a transcription hands back
        /// (`SpeechTranscription.maximumLength`).
        func text(cutAt length: Int) -> String {
            String(text.prefix(length))
        }

        /// Whether `text` has reached `length` characters: where a
        /// transcription stops on its own.
        func reaches(_ length: Int) -> Bool {
            text.count >= length
        }
    }
}
