//
//  TranscriptionLanguage.swift
//  FloorMobile
//

import Foundation
import Speech
import os

/// Which language a transcription listens in, and which language models the
/// device prepares ahead.
///
/// The associate's language — their profile's, from `GET setup` —, else the
/// device's own. Each is brought to a language the transcriber knows — `"fr"`
/// becomes `fr_FR` — and English closes the list. No choice on the
/// transcription screen (decision of 16/11): the associate dictates in their
/// own language, set in their profile.
///
/// The models themselves are not in the app: iOS downloads them on demand and
/// shares them between apps (`AssetInventory`), and it caps how many
/// languages an app holds. So the device prepares two ahead, right after the
/// launch sync — its own language and the associate's —, and the
/// transcription element downloads one only when it is not there yet
/// (`LanguageDownload`).
nonisolated struct TranscriptionLanguage: Sendable {
    /// What a transcription starts in when no candidate is supported.
    static let fallback = Locale(identifier: "en_US")

    /// The associate's language, raw as `GET setup` sends it (`"Fr"`), or
    /// `nil`.
    var associateLanguage: String?
    /// The device's language.
    var deviceLocale: Locale
    /// The transcriber's own language for `locale`, or `nil` when it has none:
    /// `SpeechTranscriber.supportedLocale(equivalentTo:)`, swapped in tests.
    var supportedLocale: @Sendable (Locale) async -> Locale?

    /// The language a new transcription starts in.
    func startLocale() async -> Locale {
        await resolved([associateLocale, deviceLocale].compactMap { $0 }).first ?? Self.fallback
    }

    /// The languages whose models are prepared ahead: the device's, and the
    /// associate's when it differs — never the same model twice.
    func localesToPrepare() async -> [Locale] {
        await resolved([deviceLocale, associateLocale].compactMap { $0 })
    }

    /// `"Fr"` → `fr`: the server sends ISO 639-1 codes, capitalised.
    private var associateLocale: Locale? {
        associateLanguage.map { Locale(identifier: $0.lowercased()) }
    }

    /// The candidates the transcriber knows, as it names them, each once.
    private func resolved(_ candidates: [Locale]) async -> [Locale] {
        var locales: [Locale] = []
        for candidate in candidates {
            guard let locale = await supportedLocale(candidate),
                  !locales.contains(where: { $0.identifier == locale.identifier })
            else { continue }
            locales.append(locale)
        }
        return locales
    }
}

nonisolated extension TranscriptionLanguage {
    /// The app's: the language of the associate signed in, and the device's.
    /// The associate is read where `AppSession.keep` writes them
    /// (`StoredValue.signedInAssociate`), not through the session: a value,
    /// not a view, with no environment to read it from.
    static var live: TranscriptionLanguage {
        TranscriptionLanguage(
            associateLanguage: StoredValue<SalesAssociateSnapshot>.signedInAssociate.get()?.preferredLanguage,
            deviceLocale: .current,
            supportedLocale: { await SpeechTranscriber.supportedLocale(equivalentTo: $0) }
        )
    }

    // MARK: - Models

    /// Makes sure `locale`'s model is on the device, downloading it when it is
    /// not. `onDownload` gets the download's progress, on the main actor,
    /// before it starts — and is not called when the model is already there:
    /// iOS shares it between apps. What `LanguageDownload` asks, and shows.
    static func prepareModel(
        for locale: Locale,
        onDownload: @MainActor @Sendable (Progress) -> Void = { _ in }
    ) async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
            return
        }
        await onDownload(request.progress)
        try await request.downloadAndInstall()
    }

    /// Prepares the models of `localesToPrepare()`, one after the other. A
    /// failure is logged and skipped: the transcription element tries again
    /// when it shows (`LanguageDownload`).
    func prepareModels() async {
        for locale in await localesToPrepare() {
            do {
                try await Self.prepareModel(for: locale)
            } catch {
                AppLog.ui.error(
                    "Transcription model for \(locale.identifier, privacy: .public) not prepared: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
