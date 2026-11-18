//
//  ClientFilterGroup.swift
//  FloorMobile
//

import SwiftUI

/// A group of filter pills in "Sort & filter" (`ClientSortFilterSheet`), as
/// the mockups draw it (canvas « Tolby - App », `C-Filtres-Texte`,
/// `C-Filtres-Applique-Noir`): its title, how many of its pills are picked on
/// the trailing edge — "2 selected", nothing while none is —, and under them
/// its pills, wrapping over as many lines as they need (`FlowLayout`).
///
/// The layout only, shared by the sheet's two kinds of group so they cannot
/// drift: one of the tenant's filters, its values to pick, and "Powered by
/// Tolby", the filters a description gave, to take off. The caller builds
/// each pill (`Pill`) — what it shows, what a touch does. The group sets the
/// pills' text style, which a pill's content takes without a word; a pill
/// placed outside a group sets its own.
///
/// In the feature rather than in the design system: it speaks "Sort &
/// filter"'s vocabulary — a group of filters, its "N selected" —, and its two
/// callers are rows of that one sheet.
///
/// ```swift
/// ClientFilterGroup(title: filter.title, pickedCount: draft.pickedCount(in: filter)) {
///     ForEach(filter.values, id: \.ref) { value in
///         Pill(isSelected: draft.isPicked(value), …) { Text(value.title) }
///     }
/// }
/// ```
struct ClientFilterGroup<Pills: View>: View {
    /// The group's name, as it reads: a filter's title, "Powered by Tolby".
    let title: String
    /// How many of its pills are picked: its "2 selected", nothing at 0.
    var pickedCount = 0
    @ViewBuilder var pills: () -> Pills

    // Computed: a generic type has no stored static property.

    /// Between the title and the pills, and between two pills of a line, the
    /// mockup's; the lines touch, each pill in its 44 pt band.
    private static var titleSpacing: CGFloat { 4 }
    private static var pillSpacing: CGFloat { 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.titleSpacing) {
            header
            FlowLayout(spacing: Self.pillSpacing, lineSpacing: 0) {
                pills()
            }
            .font(.subheadline.weight(.medium))
        }
    }

    /// The group's title, a header for VoiceOver, and its count.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .fontWeight(.medium)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if pickedCount > 0 {
                Text("\(pickedCount) selected")
                    .foregroundStyle(Color(.OnSurface.textSecondary))
            }
        }
        .font(.subheadline)
    }
}

// MARK: - Previews

#Preview("Tolby's filters to take off, a filter's values to pick") {
    @Previewable @State var understood = ["Segment · VIC", "Opted in · WhatsApp"]
    @Previewable @State var picked: Set<String> = ["VIC", "Connoisseur"]

    VStack(alignment: .leading, spacing: 24) {
        ClientFilterGroup(title: "Powered by Tolby") {
            ForEach(understood, id: \.self) { label in
                Pill(
                    isSelected: true,
                    isRemovable: true,
                    accessibilityLabel: label,
                    onToggle: { _ in understood.removeAll { $0 == label } },
                    onRemove: { understood.removeAll { $0 == label } }
                ) {
                    Text(verbatim: label)
                }
            }
        }
        ClientFilterGroup(title: "Segment", pickedCount: picked.count) {
            ForEach(["VIC", "VIP", "Repeater", "One Timer", "Connoisseur", "Explorer"], id: \.self) { segment in
                Pill(isSelected: picked.contains(segment), accessibilityLabel: segment) { selected in
                    if selected { picked.insert(segment) } else { picked.remove(segment) }
                } content: {
                    Text(verbatim: segment)
                }
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ambientBackground()
}
