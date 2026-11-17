//
//  LanguageDownload.swift
//  FloorMobile
//

import Foundation
import Observation
import os

/// The language a transcription listens in, brought to the device when it is
/// not there yet — the launch has not finished preparing it, or iOS took it
/// back: what the transcription element shows while iOS downloads it
/// (`LanguageDownloadView`), and what "Cancel download" stops.
///
/// A model, not a view model: the download itself, as `SpeechTranscription`
/// is the recording.
///
/// The models are not the app's: iOS downloads them from Apple, keeps them and
/// shares them between apps (`TranscriptionLanguage.prepareModel`). So a
/// cancel is asked of iOS, which does not document it: the download may still
/// finish, and the model then stays on the device for next time.
///
/// A task cancelled while it waits — the screen gone, "Cancel download" —
/// writes nothing: whoever cancelled it owns the state.
@Observable
final class LanguageDownload {

    enum State {
        case idle
        /// iOS downloads the language's model: its progress.
        case downloading(Progress)
        /// The model did not come, with iOS's message.
        case failed(String)
    }

    /// Asks iOS for a language's model, handing over the download's progress
    /// when it has to download it: `TranscriptionLanguage.prepareModel`,
    /// swapped in tests.
    typealias Install = (Locale, @MainActor @Sendable (Progress) -> Void) async throws -> Void

    private(set) var state: State = .idle

    private let install: Install

    init(install: @escaping Install = { try await TranscriptionLanguage.prepareModel(for: $0, onDownload: $1) }) {
        self.install = install
    }

    /// Makes sure `locale`'s model is on the device — a download under way
    /// stopped first —, showing iOS's progress while it downloads. `true` once
    /// it is there, so listening can start; `false` when it failed (`.failed`)
    /// or when the task was cancelled meanwhile, which then writes nothing.
    func prepare(_ locale: Locale) async -> Bool {
        cancel()
        do {
            try await install(locale) { progress in
                // Cancelled before iOS answered: a download nobody waits for.
                guard !Task.isCancelled else {
                    progress.cancel()
                    return
                }
                self.state = .downloading(progress)
            }
            guard !Task.isCancelled else { return false }
            state = .idle
            return true
        } catch {
            guard !Task.isCancelled else { return false }
            AppLog.ui.error(
                "Transcription model for \(locale.identifier, privacy: .public) not downloaded: \(error.localizedDescription, privacy: .public)"
            )
            state = .failed(error.localizedDescription)
            return false
        }
    }

    /// Asks iOS to stop the download under way, if any — without a promise, see
    /// the type — and comes back to `.idle`.
    func cancel() {
        if case .downloading(let progress) = state {
            progress.cancel()
        }
        state = .idle
    }
}
