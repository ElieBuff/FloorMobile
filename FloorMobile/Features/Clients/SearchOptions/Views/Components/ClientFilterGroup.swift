//
//  ClientFilterGroup.swift
//  FloorMobile
//

import SwiftUI

/// One of the tenant's filters in "Sort & filter" (`ClientSortFilterSheet`),
/// as the mockup draws it (canvas « Tolby - App », `C-Filtres-Texte`): its
/// title, how many of its values are picked on the trailing edge — "2
/// selected", nothing while none is —, and under them its values, each a
/// `Pill`, wrapping over as many lines as they need (`FlowLayout`).
///
/// It shows the draft and changes nothing: a touch on a pill is handed back
/// (`onTap`), and the sheet picks the value, lets go of it or opens its
/// calendar. A value picked with a day — "Since a date" — shows the day after
/// its name.
///
/// Not in the pill yet (decision of 17/11): a segment's coloured dot, a
/// status's point, Tolby's violet.
struct ClientFilterGroup: View {
    let filter: ClientFilter
    /// What is picked, read only.
    let draft: ClientFilterDraft
    /// A touch on one of the filter's values.
    let onTap: (ClientFilterValue) -> Void

    /// Between the title and the pills, and between two pills of a line, the
    /// mockup's; the lines touch, each pill in its 44 pt band.
    private static let titleSpacing: CGFloat = 4
    private static let pillSpacing: CGFloat = 6
    /// Between a value's name and its day, the mockup's gap inside a pill.
    private static let daySpacing: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleSpacing) {
            header
            FlowLayout(spacing: Self.pillSpacing, lineSpacing: 0) {
                ForEach(filter.values, id: \.ref) { value in
                    pill(for: value)
                }
            }
        }
    }

    /// The filter's title, a header for VoiceOver, and its count.
    private var header: some View {
        let count = draft.pickedCount(in: filter)
        return HStack(alignment: .firstTextBaseline) {
            Text(filter.title)
                .fontWeight(.medium)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if count > 0 {
                Text("\(count) selected")
                    .foregroundStyle(Color(.OnSurface.textSecondary))
            }
        }
        .font(.subheadline)
    }

    /// A value's pill: its name, then the day picked for it, if any, in the
    /// pill's secondary level.
    private func pill(for value: ClientFilterValue) -> some View {
        let day = draft.day(pickedFor: value)?.formatted(date: .abbreviated, time: .omitted)
        return Pill(
            isSelected: draft.isPicked(value),
            accessibilityLabel: [value.title, day].compactMap(\.self).joined(separator: ", ")
        ) { _ in
            onTap(value)
        } content: {
            HStack(spacing: Self.daySpacing) {
                Text(value.title)
                if let day {
                    Text(day)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline.weight(.medium))
        }
    }
}

// MARK: - Previews

#Preview("Several values, one value with its day") {
    // "Since a date" comes picked with its day: the sheet's calendar picks
    // it, a touch here only lets go of it.
    @Previewable @State var draft = ClientFilterDraft(
        options: ClientSearchOptions(filters: [.value(ref: "created-since", parameters: ["since": "2026-07-01"])])
    )

    let tier = ClientFilter(
        id: "tier", titleKey: "client.filter.tier", selectionRaw: "MULTIPLE", rank: 0,
        values: ["VIC", "VIP", "Repeater", "One Timer", "Connoisseur", "Explorer"].map { (segment: String) in
            ClientFilterValue(ref: "tier-\(segment)", labelKey: nil, label: segment, parameters: [])
        }
    )
    let created = ClientFilter(
        id: "created", titleKey: "client.filter.created", selectionRaw: "SINGLE", rank: 1,
        values: [
            ClientFilterValue(
                ref: "created-last3Months", labelKey: "client.filter.value.last3Months", label: nil, parameters: []
            ),
            ClientFilterValue(
                ref: "created-since", labelKey: "client.filter.value.since", label: nil,
                parameters: [ClientFilterValue.Parameter(name: "since", typeRaw: "date")]
            ),
        ]
    )

    VStack(alignment: .leading, spacing: 24) {
        ForEach([tier, created]) { filter in
            ClientFilterGroup(filter: filter, draft: draft) { value in
                draft.toggle(value, of: filter)
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ambientBackground()
}
