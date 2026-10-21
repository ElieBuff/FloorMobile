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
/// the transcription sheet starts, shows and stops.
///
/// It owns the recording the way `AppSession` owns the sign-in — the
/// microphone (`AudioFeed`), the analyzer and its results — and exposes what
/// a view reads: the state, the text as it is heard, the voice's level. Not a
/// view model: no view logic lives here.
///
/// `SpeechAnalyzer` with a `SpeechTranscriber` (iOS 26): on the device, with
/// a model iOS downloads per language and shares between apps
/// (`TranscriptionLanguage.prepareModel`).
@Observable
final class SpeechTranscription {

    enum State {
        case idle
        /// Getting the language model; `progress` while it downloads, `nil`
        /// while iOS checks whether it is already there.
        case preparing(Progress?)
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

    private(set) var state: State = .idle
    private(set) var transcript = Transcript()
    /// The voice's last levels, 0…1, oldest first — what the bars draw.
    private(set) var levels = Array(repeating: Float(0), count: SpeechTranscription.levelCount)

    /// The text so far, final words and words still being decided alike.
    var text: String { transcript.text }

    static let levelCount = 24
    /// A transcription stops on its own past this: a note, not a meeting.
    static let maximumDuration: Duration = .seconds(120)

    private var analyzer: SpeechAnalyzer?
    private var feed: AudioFeed?
    private var inputs: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var guardTask: Task<Void, Never>?

    // MARK: - Starting

    /// Starts listening in `locale`, after the microphone permission and the
    /// language model. A transcription already running is dropped first.
    func start(in locale: Locale) async {
        await cancel()
        transcript = Transcript()
        levels = Array(repeating: 0, count: Self.levelCount)

        guard SpeechTranscriber.isAvailable else {
            state = .failed(.unavailable)
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .failed(.microphoneDenied)
            return
        }

        state = .preparing(nil)
        do {
            try await TranscriptionLanguage.prepareModel(for: locale) { [weak self] progress in
                self?.state = .preparing(progress)
            }
            try await listen(in: locale)
            state = .listening
            watch()
        } catch {
            AppLog.ui.error("Transcription failed to start: \(error.localizedDescription, privacy: .public)")
            tearDown()
            state = .failed(.other(error.localizedDescription))
        }
    }

    /// Wires the microphone to the analyzer, and the analyzer's results to
    /// the transcript.
    private func listen(in locale: Locale) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AudioFeed.Failure.unsupportedFormat
        }

        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let feed = try AudioFeed(format: format) { input in
            continuation.yield(input)
        } onLevel: { [weak self] level in
            Task { @MainActor in self?.record(level) }
        }

        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.transcript.apply(String(result.text.characters), isFinal: result.isFinal)
                }
            } catch {
                AppLog.ui.error("Transcription results ended: \(error.localizedDescription, privacy: .public)")
            }
        }
        try await analyzer.start(inputSequence: stream)
        try feed.start()

        self.analyzer = analyzer
        self.feed = feed
        inputs = continuation
    }

    /// Stops on its own after `maximumDuration`, or when a call or another app
    /// takes the microphone — the words heard so far are kept.
    private func watch() {
        guardTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    try? await Task.sleep(for: Self.maximumDuration)
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

    private func record(_ level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    // MARK: - Stopping

    /// Stops listening and waits for the last words: `text` is final once the
    /// state is `.finished`.
    func finish() async {
        guard case .listening = state else { return }
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
    }

    /// Stops at once and drops what was heard.
    func cancel() async {
        feed?.stop()
        inputs?.finish()
        await analyzer?.cancelAndFinishNow()
        resultsTask?.cancel()
        tearDown()
        state = .idle
    }

    private func tearDown() {
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
    }
}
