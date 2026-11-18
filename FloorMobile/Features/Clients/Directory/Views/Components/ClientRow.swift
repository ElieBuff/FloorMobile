//
//  ClientRow.swift
//  FloorMobile
//

import SwiftUI

/// One client in a list, on three lines and without an avatar, as the mockup
/// has it: the salutation and the name (`ClientItem.displayLabel`, in the
/// `rowTitle` role), the segment as a tag (`.tagStyle()`) in the brand's colours
/// (`ClientSegment`), and how to reach them — email and phone on one line
/// (`ClientItem.contactLine`, in the `rowDetail` role).
///
/// Shared by every client list, whatever the client's source — the server or
/// the device both give a `ClientItem`. Only what the card holds is written:
/// a line the client has nothing for is left out — no tag without a segment
/// the brand has coloured (decision of 15/11), no contact line without an
/// email or a phone —, the name never ("Unnamed client" without one).
struct ClientRow: View {
    let client: ClientItem
    /// The brand's segment this client is in, as `GET setup` serves it; `nil`
    /// when the client has none or the brand does not list it.
    let segment: ClientSegment?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(client.displayLabel)
                .appFont(.rowTitle)
                .foregroundStyle(Color(.OnSurface.textPrimary))
            if let segment, let colors = segment.tagColors {
                Text(segment.code)
                    .tagStyle(background: colors.background, foreground: colors.foreground)
            }
            DetailLine(client.contactLine)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One line of detail under the name, in the row's look — nothing at all for
/// a value the client does not have.
private struct DetailLine: View {
    let text: String?

    init(_ text: String?) {
        self.text = text
    }

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
                .appFont(.rowDetail)
                .foregroundStyle(Color(.OnSurface.textSecondary))
        }
    }
}

// MARK: - Previews

// The segments of the dev tenant's `GET setup`, as it served them on 15/11.
#Preview("Rows") {
    List {
        ClientRow(
            client: ClientItem(
                id: "1", firstName: "Alice", lastName: "Martinez", segment: "VIC",
                primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78", salutation: "misses"
            ),
            segment: ClientSegment(code: "VIC", backgroundColorHex: "#14545F", textColorHex: "#ffffff", rank: 3)
        )
        // Without a phone: the email alone.
        ClientRow(
            client: ClientItem(
                id: "2", firstName: "Raphaël", lastName: "Van den Berg", segment: "Connoisseur",
                primaryEmail: "raphael.vandenberg@example.com", salutation: "mister"
            ),
            segment: ClientSegment(code: "Connoisseur", backgroundColorHex: "#1454600D", textColorHex: "#2A5A63", rank: 1)
        )
        // A segment the console has not coloured yet: no tag.
        ClientRow(
            client: ClientItem(id: "3", firstName: "Emma", lastName: "Rossi", segment: "Explorer"),
            segment: ClientSegment(code: "Explorer", backgroundColorHex: nil, textColorHex: nil, rank: 4)
        )
        // Without a salutation, a segment or a way to reach them: the name alone.
        ClientRow(client: ClientItem(id: "4", firstName: "Nina", lastName: "Larsen"), segment: nil)
        // No name on file: "Unnamed client", never a salutation before it.
        ClientRow(client: ClientItem(id: "5"), segment: nil)
    }
    .insetGroupedList()
}
