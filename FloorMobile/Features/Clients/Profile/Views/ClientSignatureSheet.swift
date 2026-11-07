//
//  ClientSignatureSheet.swift
//  FloorMobile
//

import PencilKit
import SwiftUI

/// Where the client signs for their new contact preferences, over the edit
/// form: each channel with its answer — those that change in bold — and the
/// day, then the pad they sign on.
///
/// "Confirm" waits for a stroke, and hands the signature to the form, which
/// sends it with the edit (`ClientEditorView`). Once a stroke is down, the
/// sheet no longer swipes away: a signature is not lost to a slip of the
/// thumb — "Cancel" says it.
struct ClientSignatureSheet: View {
    /// The client with the consents being signed for.
    let client: ClientItem
    /// The client as the form opened on them, to show what changes.
    let original: ClientItem
    let onConfirm: (ClientSignature) -> Void

    @State private var drawing = PKDrawing()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                preferences

                VStack(spacing: 8) {
                    SignaturePad(drawing: $drawing)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                    Text("Sign above")
                        .font(.footnote)
                        .foregroundStyle(Color(.OnCanvas.textSecondary))
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.cardInset)
            .ambientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(!drawing.strokes.isEmpty)
    }

    /// The consents as they will stand, and the day.
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contact preferences of \(client.displayLabel)")
                .font(.headline)
                .foregroundStyle(Color(.OnCanvas.textPrimary))

            ForEach(ClientItem.OptIns.Channel.allCases, id: \.self) { channel in
                HStack {
                    Text(channel.label)
                    Spacer()
                    if let optIns = client.optIns {
                        Text(optIns.answer(for: channel))
                    }
                }
                .font(.subheadline.weight(changedChannels.contains(channel) ? .semibold : .regular))
                .foregroundStyle(Color(.OnCanvas.textPrimary))
                .accessibilityElement(children: .combine)
            }

            Text(Date.now.formatted(date: .long, time: .omitted))
                .font(.footnote)
                .foregroundStyle(Color(.OnCanvas.textSecondary))
        }
    }

    /// The channels whose answer the client is changing, shown in bold.
    private var changedChannels: [ClientItem.OptIns.Channel] {
        guard let optIns = client.optIns, let before = original.optIns else { return [] }
        return optIns.changedChannels(from: before)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "Cancel"), role: .cancel) {
                dismiss()
            }
        }
        ToolbarItem(placement: .bottomBar) {
            Button(String(localized: "Clear")) {
                drawing = PKDrawing()
            }
            .disabled(drawing.strokes.isEmpty)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "Confirm")) {
                confirm()
            }
            .disabled(drawing.strokes.isEmpty)
        }
    }

    /// Hands the signature to the form, and closes.
    private func confirm() {
        guard let png = drawing.signaturePNG() else { return }
        let signature = ClientSignature(png: png, signedAt: .now)
        dismiss()
        onConfirm(signature)
    }
}

// MARK: - Previews

#Preview {
    let original = ClientItem(
        id: "1", firstName: "Alice", lastName: "Martinez",
        optIns: ClientItem.OptIns(email: true, directMessage: false, call: false, wechat: false, line: false)
    )
    var edited = original
    edited.optIns?.call = true

    return Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientSignatureSheet(client: edited, original: original) { _ in }
        }
}
