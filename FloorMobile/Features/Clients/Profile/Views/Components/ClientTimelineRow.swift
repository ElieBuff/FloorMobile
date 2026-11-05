//
//  ClientTimelineRow.swift
//  FloorMobile
//

import SwiftUI

/// One line of a client's timeline, in their profile's "Activity" tab: what
/// it is, its title, its subtitle on one line, then its date and status.
/// Read only — a line opens nothing yet.
///
/// The symbol of its kind stands for it, not the reason's badge
/// (`ReasonIcon`, the agenda's): the reason is read in the subtitle.
struct ClientTimelineRow: View {
    let item: ClientTimelineItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .frame(width: 24)
                // Read first by VoiceOver: the kind, which the title may not say.
                .accessibilityLabel(item.kind.displayLabel)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title ?? item.kind.displayLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color(.OnSurface.textPrimary))
                    // A purchase names every product: the screen cuts what it
                    // cannot hold, as the server expects.
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitleText)
                        .font(.caption)
                        .foregroundStyle(Color(.OnSurface.textSecondary))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(item.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(Color(.OnSurface.textSecondary))
                if let status = item.statusLabel {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(Color(.OnSurface.textTertiary))
                }
            }
        }
        // One element for VoiceOver: kind, title, subtitle, date, status.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview {
    List {
        Section {
            ClientTimelineRow(item: ClientTimelineItem(
                id: "1", kind: .transaction, date: .now, status: "PAID",
                title: "VESTE ACACIA · T-SHIRT CESAR",
                subtitle: [.itemCount(2), .amount(237.9, currency: "EUR")]
            ))
            .listRowInsets(.cardRow)
            ClientTimelineRow(item: ClientTimelineItem(
                id: "2", kind: .event, date: .now, status: "PLANNED", title: "Fitting",
                subtitle: [.reason("BACK_IN_STOCK"), .meetingType("IN_PERSON"), .text("New season pieces")]
            ))
            .listRowInsets(.cardRow)
            ClientTimelineRow(item: ClientTimelineItem(
                id: "3", kind: .conversation, date: .now, status: "ACTIVE", title: nil,
                subtitle: [.text("Perfect, thank you")]
            ))
            .listRowInsets(.cardRow)
        }
    }
    .cardList()
    .ambientBackground()
}
