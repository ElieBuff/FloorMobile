//
//  TranscriptionView.swift
//  FloorMobile
//

import SwiftUI

/// Voice to text, as an element a screen places in a sheet of its own, drawn
/// as the mockups draw it (canvas « Tolby - App »). Two views:
/// - **listening** (`C-Voix-Ecoute-Anneau-Long-3L`): the listening pebble and
///   its rings, which swell with the voice (`ListeningPebble`), then the words,
///   as they are heard, in a box of three lines that scrolls — nothing before
///   the first. A screen that paints the ambient background behind it keeps
///   that background still (`.ambientBackground(followsScroll: false)`): the
///   box is the element's first scroll view;
/// - **downloading** (`C-Voix-Langue`), when the language is not on the device
///   yet: `LanguageDownloadView`, and "Cancel download" in place of the
///   screen's action, which closes the sheet.
///
/// It listens in the associate's language — set in their profile —, else the
/// device's (`TranscriptionLanguage`): no choice here (decision of 16/11), the
/// associate dictates in their own language. The app prepares it right after
/// the launch sync (`TranscriptionLanguage.prepareModels`), so the download
/// shows only when that one has not finished, has failed, or iOS has taken
/// the model back.
///
/// It starts listening as soon as it shows, drops what was heard when it goes,
/// and stops — keeping the words — when the app leaves the screen.
///
/// Two models, one per view (decision of 16/11): the screen's transcription
/// (`SpeechTranscription`) and the element's own download
/// (`LanguageDownload`). The element chains them — the language first, then
/// the listening — in one task at a time: a new one cancels the one before,
/// which then writes nothing.
///
/// No bar or title of its own (decision of 16/11): the screen that opens the
/// sheet decides them, and what its action does — "Voice search" in "Sort &
/// filter" (`ClientVoiceSearchSheet`). The screen holds the transcription and
/// hands it here, with its action, which the element places at the bottom:
/// its "Done" stops the listening and reads the final text through it
/// (`SpeechTranscription.finish()`, `canFinish`), which a callback with the
/// text could not do — the last words arrive after the stop.
///
/// ```swift
/// @State private var transcription = SpeechTranscription(maximumLength: 500)
///
/// TranscriptionView(transcription: transcription, language: .live) {
///     Button("Done") { Task { onText(await transcription.finish()) } }
///         .disabled(!transcription.canFinish)
///         .bottomActionStyle()
/// }
/// ```
struct TranscriptionView<Action: View>: View {
    /// The screen's transcription: started here, finished by the screen.
    let transcription: SpeechTranscription
    /// The language listening starts in.
    let language: TranscriptionLanguage
    /// The screen's action, at the bottom: it gives way to "Cancel download"
    /// while the language downloads.
    @ViewBuilder var action: () -> Action

    @State private var download = LanguageDownload()
    /// The language listened in, or being brought to the device.
    @State private var locale: Locale?
    /// The language, then the listening, under way: cancelled by the next.
    @State private var starting: Task<Void, Never>?
    /// Where the words are scrolled: at their end as they are heard.
    @State private var wordsPosition = ScrollPosition(edge: .top)
    /// Whether words are hidden above the box: its top line then fades.
    @State private var wordsHiddenAbove = false
    /// The words' line, the mockup's 26 pt, scaled like their text.
    @ScaledMetric(relativeTo: .body) private var wordsLineHeight: CGFloat = 26
    /// How far down the box's top fades, the mockup's 30 pt, scaled the same.
    @ScaledMetric(relativeTo: .body) private var wordsFade: CGFloat = 30
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// The words' margin on each side, the mockup's. Computed: a generic type
    /// has no stored static property.
    private static var wordsInset: CGFloat { 32 }

    var body: some View {
        VStack(spacing: 0) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .safeAreaBar(edge: .bottom) {
            if isDownloading {
                Button(String(localized: "Cancel download")) {
                    cancelDownload()
                }
                .bottomActionStyle(prominent: false)
            } else {
                action()
            }
        }
        .task {
            listen(in: await language.startLocale())
        }
        .onDisappear {
            starting?.cancel()
            download.cancel()
            Task { await transcription.cancel() }
        }
        // A call or the app leaving the screen stops the listening, keeping
        // what was heard: the screen's "Done" still hands it back.
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await transcription.finish() }
        }
    }

    /// The download while the language downloads; else what failed; else the
    /// listening.
    @ViewBuilder
    private var content: some View {
        if case .downloading(let progress) = download.state, let locale {
            LanguageDownloadView(locale: locale, progress: progress)
                .padding(.top, 16)
        } else if let failure {
            failed(failure)
        } else {
            ListeningPebble(level: transcription.level, isListening: isListening)
                .padding(.top, 24)
            heard
                .padding(.top, 10)
        }
    }

    private var isDownloading: Bool {
        if case .downloading = download.state { return true }
        return false
    }

    /// What failed: the download — the listening never started then — or the
    /// listening.
    private var failure: SpeechTranscription.Failure? {
        if case .failed(let message) = download.state { return .other(message) }
        if case .failed(let failure) = transcription.state { return failure }
        return nil
    }

    private var isListening: Bool {
        if case .listening = transcription.state { return true }
        return false
    }

    /// Whether the listening has stopped, the words final or about to be.
    private var isStopped: Bool {
        switch transcription.state {
        case .finishing, .finished: true
        default: false
        }
    }

    // MARK: - Words

    /// The words, once one is heard, in quotes — opened while listening,
    /// closed once stopped, as the mockup writes them —, the final ones in
    /// ink, the ones still being decided fainter. In 17 pt Medium, iOS's
    /// nearest to the mockup's 18, on its 26 pt line, at its 32 pt from the
    /// edges.
    ///
    /// In a box of three lines under the pebble, as the mockup draws a long
    /// text (decision of 17/11). A short text sits at its top (`.alignment` at
    /// the top); a longer one scrolls, brought back to its end at every word
    /// heard, so the last three lines stay in view while the associate speaks,
    /// the top one fading out while words are hidden above (`wordsMask`) —
    /// the start a swipe away. Not iOS's `.sizeChanges` anchor at the bottom:
    /// it does not follow the text as it grows. Nor iOS's own edge effect at
    /// the top: a blur made for bars, which would add to the mockup's fade.
    private var heard: some View {
        ScrollView {
            if !transcription.text.isEmpty {
                Text(heardText)
                    .font(.body.weight(.medium))
                    .lineHeight(.exact(points: wordsLineHeight))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Self.wordsInset)
            }
        }
        .frame(height: 3 * wordsLineHeight)
        .scrollPosition($wordsPosition)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectHidden(true, for: .top)
        .defaultScrollAnchor(.top, for: .alignment)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 0
        } action: { _, hidden in
            wordsHiddenAbove = hidden
        }
        .mask { wordsMask }
        .onChange(of: transcription.text) {
            wordsPosition.scrollTo(edge: .bottom)
        }
    }

    /// The box's top fading out over `wordsFade` while words are hidden above,
    /// clear otherwise: a gradient that never changes, under ink whose opacity
    /// does — an opacity animates, a gradient's stops do not. Animated for
    /// all: a fade is what the HIG put in place of motion.
    private var wordsMask: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                Color.black
                    .opacity(wordsHiddenAbove ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: wordsHiddenAbove)
            }
            .frame(height: wordsFade)
            Color.black
        }
    }

    /// The quotes and the two parts in one text, each part in its own colour.
    /// An `AttributedString` rather than `Text` interpolation: what the
    /// associate said is not a string to translate, and interpolating would
    /// add a key to the string catalog.
    ///
    /// Shown whole, not cut at `maximumLength` as "Done" hands it back: past
    /// the limit, listening stops at once, so the screen shows at most the
    /// last result's few words more — and 30 s of speech stay well under the
    /// 500 characters of a filter's sentence.
    private var heardText: AttributedString {
        var finalized = AttributedString(transcription.transcript.finalized)
        finalized.foregroundColor = Color(.OnSurface.textPrimary)
        var volatile = AttributedString(transcription.transcript.volatile)
        volatile.foregroundColor = Color(.OnSurface.textTertiary)
        var opening = AttributedString("“")
        opening.foregroundColor = Color(.OnSurface.textPrimary)
        var closing = AttributedString(isStopped ? "”" : "")
        closing.foregroundColor = Color(.OnSurface.textPrimary)
        return opening + finalized + volatile + closing
    }

    // MARK: - Failure

    @ViewBuilder
    private func failed(_ failure: SpeechTranscription.Failure) -> some View {
        switch failure {
        case .microphoneDenied:
            ContentUnavailableView {
                Label(String(localized: "Microphone access is off"), systemImage: "mic.slash")
            } description: {
                Text(String(localized: "Allow the microphone in Settings to dictate."))
            } actions: {
                Button(String(localized: "Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        case .unavailable:
            ContentUnavailableView(
                String(localized: "Dictation isn't available on this device"),
                systemImage: "mic.slash"
            )
        case .other(let message):
            ContentUnavailableView {
                Label(String(localized: "Couldn't start dictation"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(String(localized: "Try again")) {
                    retry()
                }
            }
        }
    }

    // MARK: - Actions

    /// Listens in `newLocale`, from the start: the task under way cancelled —
    /// it then writes nothing —, the listening stopped and its words dropped,
    /// the language brought to the device when it is not there yet
    /// (`LanguageDownload`), then the listening started.
    private func listen(in newLocale: Locale) {
        starting?.cancel()
        locale = newLocale
        starting = Task {
            await transcription.cancel()
            guard !Task.isCancelled, await download.prepare(newLocale) else { return }
            await transcription.start(in: newLocale)
        }
    }

    /// "Try again": the same language, by the same path.
    private func retry() {
        guard let locale else { return }
        listen(in: locale)
    }

    /// "Cancel download": the task under way cancelled — so a download iOS
    /// finishes anyway opens nothing —, iOS asked to stop the download, and
    /// the sheet closed: without the language there is nothing to listen in,
    /// and no other to pick.
    private func cancelDownload() {
        starting?.cancel()
        download.cancel()
        dismiss()
    }
}

// MARK: - Previews

#Preview("Listening") {
    @Previewable @State var transcription = SpeechTranscription(maximumLength: 500)

    Color.clear
        .sheet(isPresented: .constant(true)) {
            TranscriptionView(transcription: transcription, language: .live) {
                Button {} label: {
                    Text(verbatim: "Done")
                }
                .bottomActionStyle()
            }
            .presentationDetents([.medium])
        }
}
