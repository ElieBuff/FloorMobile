//
//  TranscriptionSheet.swift
//  FloorMobile
//

import Speech
import SwiftUI

/// The voice-to-text sheet: it listens as soon as it opens, shows the voice
/// as moving bars and the words as they are heard, and hands the text back on
/// "Done". "Cancel", or a swipe down, drops it.
///
/// Opened by `.transcription(isPresented:onText:)`, never directly: a page
/// only places its own button.
struct TranscriptionSheet: View {
    /// The languages: where the sheet starts, and the last pick to remember.
    let language: TranscriptionLanguage
    /// The final text, once, on "Done" — never empty.
    let onText: (String) -> Void

    @State private var transcription = SpeechTranscription()
    @State private var locale: Locale?
    @State private var supportedLocales: [Locale] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VoiceBars(levels: transcription.levels, isActive: isListening)
                    .frame(height: 56)
                    .accessibilityHidden(true)
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            let start = await language.startLocale()
            locale = start
            await transcription.start(in: start)
            supportedLocales = await Self.sortedSupportedLocales()
        }
        .onDisappear {
            Task { await transcription.cancel() }
        }
        // A call or the app leaving the screen stops the listening, keeping
        // what was heard: "Done" still hands it back.
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await transcription.finish() }
        }
    }

    private var isListening: Bool {
        if case .listening = transcription.state { return true }
        return false
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch transcription.state {
        case .idle, .preparing:
            preparing
        case .listening, .finishing, .finished:
            heard
        case .failed(let failure):
            failed(failure)
        }
    }

    private var preparing: some View {
        VStack(spacing: 12) {
            if case .preparing(let progress?) = transcription.state {
                ProgressView(progress)
                    .tint(Color(.Base.ink))
            } else {
                ProgressView()
            }
            Text(String(localized: "Preparing \(languageName(locale))…"))
                .font(.subheadline)
                .foregroundStyle(Color(.OnSurface.textSecondary))
        }
    }

    /// The final words in full ink, the ones still being decided fainter.
    private var heard: some View {
        ScrollView {
            Group {
                if transcription.text.isEmpty {
                    Text(String(localized: "Speak: the text appears here."))
                        .foregroundStyle(Color(.OnSurface.textTertiary))
                } else {
                    let finalized = Text(transcription.transcript.finalized)
                        .foregroundStyle(Color(.OnSurface.textPrimary))
                    let volatile = Text(transcription.transcript.volatile)
                        .foregroundStyle(Color(.OnSurface.textTertiary))
                    Text("\(finalized)\(volatile)")
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .defaultScrollAnchor(.bottom)
    }

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
                    restart()
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Cancel"), role: .cancel) {
                dismiss()
            }
        }
        ToolbarItem(placement: .principal) {
            languageMenu
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "Done")) {
                Task { await done() }
            }
            .disabled(transcription.text.isEmpty)
        }
    }

    /// The language listened in: another one starts over, downloading its
    /// model when the device does not have it yet.
    private var languageMenu: some View {
        Menu {
            Picker(String(localized: "Language"), selection: Binding(
                get: { locale?.identifier ?? "" },
                set: { pick(Locale(identifier: $0)) }
            )) {
                ForEach(supportedLocales, id: \.identifier) { option in
                    Text(languageName(option)).tag(option.identifier)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(languageName(locale))
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color(.OnSurface.textPrimary))
        }
        .accessibilityLabel(String(localized: "Language"))
        .accessibilityValue(languageName(locale))
    }

    // MARK: - Actions

    /// Waits for the last words, then hands the text back and closes.
    private func done() async {
        await transcription.finish()
        let text = transcription.text
        guard !text.isEmpty else { return }
        onText(text)
        dismiss()
    }

    private func pick(_ newLocale: Locale) {
        guard newLocale.identifier != locale?.identifier else { return }
        locale = newLocale
        language.lastPicked.set(newLocale.identifier)
        restart()
    }

    private func restart() {
        guard let locale else { return }
        Task { await transcription.start(in: locale) }
    }

    /// "Français (France)", in the device's language.
    private func languageName(_ locale: Locale?) -> String {
        guard let locale else { return "" }
        return Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    private static func sortedSupportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales.sorted {
            (Locale.current.localizedString(forIdentifier: $0.identifier) ?? $0.identifier)
                < (Locale.current.localizedString(forIdentifier: $1.identifier) ?? $1.identifier)
        }
    }
}

// MARK: - Voice bars

/// The voice, as bars that rise and fall with its last levels — still when
/// nothing is heard, and still when Reduce Motion is on.
private struct VoiceBars: View {
    let levels: [Float]
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let count = levels.count
            guard count > 0 else { return }
            let spacing: CGFloat = 4
            let width = (size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            for (index, level) in levels.enumerated() {
                let shown = reduceMotion || !isActive ? 0.15 : max(CGFloat(level), 0.08)
                let height = size.height * shown
                let rect = CGRect(
                    x: CGFloat(index) * (width + spacing),
                    y: (size.height - height) / 2,
                    width: width,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(Color(.Base.ink)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: levels)
        .frame(maxWidth: 280)
    }
}

// MARK: - Previews

#Preview("Listening") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            TranscriptionSheet(language: .live) { _ in }
                .presentationDetents([.medium])
        }
}
