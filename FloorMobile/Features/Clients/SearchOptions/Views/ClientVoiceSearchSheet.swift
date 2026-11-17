//
//  ClientVoiceSearchSheet.swift
//  FloorMobile
//

import SwiftUI

/// "Voice search", opened by the microphone of "Sort & filter"'s sentence
/// (`ClientSortFilterSheet`): the clients wanted, said rather than typed.
/// The listening element (`TranscriptionView`) under the title and the close
/// button; "Done", the action the element places at the bottom, stops the
/// listening, waits for the last words, hands the text back and closes — the
/// element swaps it for "Cancel download" while a language downloads. The
/// close button, or a swipe down, closes without it.
///
/// The sheet is the screen's, the listening the design system's (decision of
/// 16/11). Tolby's steps after the voice — what it understood, "Show N
/// clients" (mockup `C-Voix-Compris`) — will join here.
struct ClientVoiceSearchSheet: View {
    /// The text heard, once, on "Done" — never empty.
    let onText: (String) -> Void

    /// Listening for a filter's sentence: no longer than the field takes.
    @State private var transcription = SpeechTranscription(maximumLength: ClientFilterDraft.maximumTextLength)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TranscriptionView(transcription: transcription, language: .live) {
                doneButton
            }
            .sheetBackground()
            .navigationTitle(Text("Voice search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The system's close button, as in "Sort & filter".
                    Button(role: .close) {
                        dismiss()
                    }
                    .barButtonStyle()
                }
            }
        }
    }

    /// Waiting until a word is heard, and while the listening stops
    /// (`SpeechTranscription.canFinish`).
    private var doneButton: some View {
        Button(String(localized: "Done")) {
            Task { await done() }
        }
        .disabled(!transcription.canFinish)
        .bottomActionStyle()
    }

    /// Stops the listening, waits for the last words, hands them back and
    /// closes.
    private func done() async {
        let text = await transcription.finish()
        guard !text.isEmpty else { return }
        onText(text)
        dismiss()
    }
}

// MARK: - Previews

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientVoiceSearchSheet { _ in }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
