//
//  View+Transcription.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// Voice to text: the action a page's own button triggers, whatever its
    /// shape. Setting `isPresented` opens the transcription sheet, which
    /// listens at once; `onText` gets the final text, once, when the associate
    /// taps "Done" — never on "Cancel". What the page does with it (append,
    /// replace) is the page's call.
    ///
    /// ```swift
    /// Button { isTranscribing = true } label: { Image(systemName: "mic") }
    ///     .transcription(isPresented: $isTranscribing) { note += $0 }
    /// ```
    func transcription(isPresented: Binding<Bool>, onText: @escaping (String) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            TranscriptionSheet(language: .live, onText: onText)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Previews

/// Any button, the action, and what it hands back.
private struct TranscriptionUsagePreview: View {
    @State private var isTranscribing = false
    @State private var note = ""

    var body: some View {
        VStack(spacing: 16) {
            Button {
                isTranscribing = true
            } label: {
                Label(String(localized: "Dictate"), systemImage: "mic")
            }
            .buttonStyle(.bordered)

            Text(note.isEmpty ? "—" : note)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .transcription(isPresented: $isTranscribing) { text in
            note += note.isEmpty ? text : " " + text
        }
    }
}

#Preview("Usage") {
    TranscriptionUsagePreview()
}
