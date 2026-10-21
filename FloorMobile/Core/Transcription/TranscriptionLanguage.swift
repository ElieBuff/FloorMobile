//
//  TranscriptionLanguage.swift
//  FloorMobile
//

import Foundation
import Speech
import os

/// Which language a transcription starts in, and which language models the
/// device prepares ahead.
///
/// Three candidates, in order: the language last picked in the sheet (a
/// preference of the device), the associate's language from `GET setup`, the
/// device's own. Each is brought to a language the transcriber knows — `"fr"`
/// becomes `fr_FR` — and English closes the list.
///
/// The models themselves are not in the app: iOS downloads them on demand and
/// shares them between apps (`AssetInventory`), and it caps how many
/// languages an app holds. So the device prepares two at most ahead — its
/// own language and the associate's — and any other is downloaded when picked
/// in the sheet.
nonisolated struct TranscriptionLanguage: Sendable {
    /// The associate's language, raw as `GET setup` sends it (`"Fr"`), or
    /// `nil`.
    var associateLanguage: String?
    /// The device's language.
    var deviceLocale: Locale
    /// The language last picked in the sheet, as a locale identifier.
    var lastPicked: StoredValue<String>
    /// The transcriber's own language for `locale`, or `nil` when it has none:
    /// `SpeechTranscriber.supportedLocale(equivalentTo:)`, swapped in tests.
    var supportedLocale: @Sendable (Locale) async -> Locale?

    /// The language a new transcription starts in.
    func startLocale() async -> Locale {
        let last = lastPicked.get().map(Locale.init(identifier:))
        return await resolved([last, associateLocale, deviceLocale].compactMap { $0 }).first
            ?? Self.fallback
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

    /// What a transcription starts in when no candidate is supported.
    static let fallback = Locale(identifier: "en_US")
}

nonisolated extension TranscriptionLanguage {
    /// The app's: the associate's language from the store, the device's, the
    /// device's last pick.
    static var live: TranscriptionLanguage {
        TranscriptionLanguage(
            associateLanguage: LocalStore.live.preferredLanguage.get(),
            deviceLocale: .current,
            lastPicked: .userDefaults(.transcriptionLanguage),
            supportedLocale: { await SpeechTranscriber.supportedLocale(equivalentTo: $0) }
        )
    }

    // MARK: - Models

    /// Makes sure `locale`'s model is on the device, downloading it when it is
    /// not. `onDownload` gets the download's progress, on the main actor,
    /// before it starts — and is not called when the model is already there:
    /// iOS shares it between apps.
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
    /// failure is logged and skipped: the sheet tries again when it opens.
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
