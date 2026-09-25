//
//  NowMarker.swift
//  FloorMobile
//

import SwiftUI

/// The "you are here" rule in the day's rail: the time on a glass pill, and a
/// hairline running from it to the end of the appointment.
///
/// One drawing, two placements — laid across the row of the appointment under
/// way (see `EventRow`), or on a line of its own in the gap between two. The
/// pill sits at the same inset either way, so the two read as one rule coming
/// down the day rather than as two components.
///
/// ## Why a pill rather than a dot
///
/// The time has to be legible over a card, not only over the background, and a
/// bare label there either fights the client's name or disappears into it.
/// Glass gives it a ground of its own without adding a colour to the palette.
/// It also frees the rail's left gutter, which is the appointment's own start
/// hour — two times a few minutes apart in one column read as a mistake.
///
/// ## Why it stops at the card's edge
///
/// The line ends where the appointment ends, which is what makes it say more
/// than the hour: not just "it is 13:05" but "13:05 *of this slot*". Run off
/// the screen instead and it becomes a section separator again.
struct NowMarker: View {
    let date: Date

    /// Gutter (40) plus the row's spacing (10), less a third of the pill: it
    /// straddles the card's leading edge instead of floating in the margin.
    private static let leadingInset: CGFloat = 34

    var body: some View {
        HStack(spacing: 0) {
            Text(date, format: .dateTime.hour().minute())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.Accent.now))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                // Untinted on purpose. `Glass.tint(_:)` expects a solid colour
                // and handles the translucency itself; handing it a faded one
                // paints over the material instead of colouring it, and the
                // refraction — the capsule taking on whatever is behind it —
                // is the only thing that makes this read as glass at all. The
                // colour is carried by the text.
                .glassEffect(.regular, in: .capsule)

            // No width of its own: it takes whatever is left, which is exactly
            // the card's trailing edge in both placements.
            Rectangle()
                .fill(Color(.Accent.now).opacity(0.5))
                .frame(height: 1)
        }
        .padding(.leading, Self.leadingInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Now, \(date.formatted(date: .omitted, time: .shortened))"))
    }
}

// MARK: - Previews

#Preview("On its own, between two appointments") {
    VStack(alignment: .leading, spacing: 10) {
        NowMarker(date: .now)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .ambientBackground()
}

