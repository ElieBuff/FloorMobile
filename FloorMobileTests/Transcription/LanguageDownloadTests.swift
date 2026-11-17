//
//  LanguageDownloadTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// A language brought to the device: what shows while iOS downloads it, and
/// that a task cancelled meanwhile — the screen gone, "Cancel download" —
/// writes nothing. iOS's call is a fake held at a `Gate`: no microphone, no
/// network.
@Suite("Language download")
@MainActor
struct LanguageDownloadTests {

    private static let french = Locale(identifier: "fr_FR")

    @Test("A language already on the device is ready at once, no download shown")
    func alreadyThere() async {
        let download = LanguageDownload { @MainActor _, _ in }

        #expect(await download.prepare(Self.french))
        #expect(Self.isIdle(download.state))
    }

    @Test("A download shows iOS's progress, then the language is ready")
    func downloadShowsProgress() async {
        let gate = Gate()
        let progress = Progress(totalUnitCount: 100)
        let download = LanguageDownload { @MainActor _, onDownload in
            onDownload(progress)
            await gate.wait()
        }

        let task = Task { await download.prepare(Self.french) }
        await gate.reached()
        #expect(Self.progress(of: download.state) === progress)

        gate.open()
        #expect(await task.value)
        #expect(Self.isIdle(download.state))
    }

    @Test("A download that fails says why, and the language is not ready")
    func failureSaysWhy() async {
        let download = LanguageDownload { @MainActor _, _ in throw NoNetwork() }

        #expect(await download.prepare(Self.french) == false)
        guard case .failed(let message) = download.state else {
            Issue.record("Expected a failure, got \(download.state)")
            return
        }
        #expect(message == NoNetwork().errorDescription)
    }

    @Test("\"Cancel download\" stops iOS's progress, and the task cancelled writes nothing when iOS finishes anyway")
    func cancelDuringDownload() async {
        let gate = Gate()
        let progress = Progress(totalUnitCount: 100)
        let download = LanguageDownload { @MainActor _, onDownload in
            onDownload(progress)
            await gate.wait()
        }

        let task = Task { await download.prepare(Self.french) }
        await gate.reached()
        task.cancel()
        download.cancel()
        #expect(Self.isIdle(download.state))
        #expect(progress.isCancelled)

        gate.open()
        #expect(await task.value == false)
        #expect(Self.isIdle(download.state))
    }

    @Test("A download iOS starts after the task was cancelled is stopped and never shown")
    func progressAfterCancel() async {
        let gate = Gate()
        let progress = Progress(totalUnitCount: 100)
        let download = LanguageDownload { @MainActor _, onDownload in
            await gate.wait()
            onDownload(progress)
        }

        let task = Task { await download.prepare(Self.french) }
        await gate.reached()
        task.cancel()
        gate.open()

        #expect(await task.value == false)
        #expect(progress.isCancelled)
        #expect(Self.isIdle(download.state))
    }

    // MARK: - Helpers

    private struct NoNetwork: LocalizedError {
        var errorDescription: String? { "The network is unreachable." }
    }

    private static func isIdle(_ state: LanguageDownload.State) -> Bool {
        if case .idle = state { return true }
        return false
    }

    private static func progress(of state: LanguageDownload.State) -> Progress? {
        if case .downloading(let progress) = state { return progress }
        return nil
    }
}
