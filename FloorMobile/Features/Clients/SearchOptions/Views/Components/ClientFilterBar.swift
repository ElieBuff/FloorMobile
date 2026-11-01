//
//  ClientFilterBar.swift
//  FloorMobile
//

import SwiftUI

/// The sentence of "Filter" (`ClientFilterPickerView`), pinned above its
/// filters, so over "No filters yet" too: a sentence gives conditions of its
/// own, outside the catalog. The clients wanted in the associate's own words,
/// typed or dictated (`FormDictateButton`, `.transcription`), what is
/// dictated added after what is there (`String.append(dictation:)`).
///
/// The arrow sends the sentence for its filters (`ClientFilterEditor`),
/// for up to 80 s, and leaves it in the field, to be reworded: the filters it
/// describes become pills under the card (`Pill`), in place of the last
/// sentence's, and what no filter covers is said under them. The arrow goes
/// once the filters are back, and comes back when the sentence changes: the
/// same words are never sent twice. The field goes with the sheet — "Apply"
/// takes the ticks and the pills, never the field.
///
/// Under the card, each when there is one: the draft's total, or
/// "Calculating…" while it is counted; the pills — the last sentence's, in
/// this sheet or applied before —; what that sentence left uncovered; why
/// the last request failed.
struct ClientFilterBar: View {
    /// The sheet's draft — its sentence, and the pills and words that came
    /// back for it — and its total.
    @Bindable var editor: ClientFilterEditor

    @State private var isDictating = false
    @FocusState private var isTextFocused: Bool

    /// The arrow's size in the layout, the microphone's beside it.
    private static let sendSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            textField
            if editor.isCounting {
                note(Text("Calculating…"))
            } else if let total = editor.total {
                note(Text("\(total) clients"))
            }
            if !editor.draft.filterItems.isEmpty {
                pills
            }
            if !editor.draft.notUnderstood.isEmpty {
                note(Text("Not understood: \(editor.draft.notUnderstood, format: .list(type: .and))"))
            }
            if let failure = editor.draft.failure {
                note(Text(failure))
            }
        }
        .padding(.bottom, 8)
    }

    /// The sentence, in a card: up to four lines, so a dictated one reads
    /// whole, then the microphone, and the arrow while there are words to
    /// send. A tap anywhere on the card puts the caret in the text, as in
    /// `FormTitleRow`. Not `FormTitleRow` or `FormNoteRow`: a bar wants
    /// neither a label nor a reserved height.
    private var textField: some View {
        HStack(spacing: 9) {
            TextField(String(localized: "Describe the clients you want"), text: $editor.draft.text, axis: .vertical)
                .lineLimit(1...4)
                .font(.body)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .focused($isTextFocused)
            FormDictateButton {
                isDictating = true
            }
            sendButton
        }
        .padding(.horizontal, AppSpacing.cardInset)
        .padding(.vertical, 10)
        .cardStyle()
        .contentShape(.rect)
        .onTapGesture { isTextFocused = true }
        .padding(.horizontal, 16)
        .transcription(isPresented: $isDictating) { dictated in
            editor.draft.text.append(dictation: dictated)
        }
    }

    /// The arrow that sends the sentence for its filters, while there are
    /// words to send; a spinner in its place while they are on their way.
    @ViewBuilder
    private var sendButton: some View {
        if editor.draft.hasPendingText {
            ProgressView()
                .frame(width: Self.sendSize, height: Self.sendSize)
                .accessibilityLabel(String(localized: "Reading the sentence"))
        } else if editor.draft.canSend {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.Base.ink))
                    .tapTarget(drawnSize: Self.sendSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Send"))
        }
    }

    /// The pills of the sentence sent, on one line that scrolls, each with an
    /// X that takes its filter off the draft — and lets the same sentence be
    /// sent again, to bring it back.
    private var pills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(editor.draft.filterItems) { item in
                    Pill(label: item.label) {
                        editor.draft.remove(item)
                    }
                }
            }
            // Room for each X's 44pt target, as `Pill` asks: a scroll view
            // takes no tap past its edges.
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    /// A line under the card: the total, what the last sentence left out, or
    /// why its request failed.
    private func note(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(Color(.OnCanvas.textSecondary))
            .padding(.horizontal, 16)
    }

    /// Sends the sentence for its filters, and puts the keyboard away, for
    /// the pills to come.
    private func send() {
        editor.draft.send()
        isTextFocused = false
    }
}
