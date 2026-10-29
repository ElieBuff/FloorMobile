//
//  Pill.swift
//  FloorMobile
//

import SwiftUI

/// A label in a capsule: a filter applied, under the sentence of "Filter" —
/// each filter the sentence described —, with an X that takes it off when
/// the caller says what removing does (`onRemove`). The card's fill on the
/// canvas, like the sentence's card above, so a row of them reads as part of
/// the screen. Only the X removes it; its 44pt target (`tapTarget`) reaches
/// past the capsule, 6pt above and below — (44 − `removeSize`) / 2, less the
/// capsule's vertical padding —: a scroll view holding pills, which takes no
/// tap past its edges, leaves them that room.
///
/// Not the system's search tokens (`searchable(text:tokens:)`): they live in a
/// search field, before its text, and go with the delete key, where a pill
/// here sits under a multi-line field, dictated as often as typed, and must
/// say how to take it off.
///
/// ```swift
/// Pill(label: item.label) {
///     draft.remove(item)
/// }
/// ```
struct Pill: View {
    let label: String
    /// What the X does; `nil` for a pill without one.
    var onRemove: (() -> Void)? = nil

    /// The X's size in the layout; its target is Apple's 44pt.
    private static let removeSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .lineLimit(1)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(.OnSurface.textSecondary))
                        .tapTarget(drawnSize: Self.removeSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Remove \(label)"))
            }
        }
        .padding(.leading, 12)
        // The X brings its own room; without it, the capsule is even.
        .padding(.trailing, onRemove == nil ? 12 : 6)
        .padding(.vertical, 6)
        .background(Color(.OnCanvas.surface), in: .capsule)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var labels = ["VIP clients", "Spent over 10,000 this year", "No email opt-in"]

    VStack(alignment: .leading, spacing: 16) {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    Pill(label: label) {
                        labels.removeAll { $0 == label }
                    }
                }
            }
            .padding(.horizontal, 16)
            // The room the X's target needs, as the doc says.
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        // Without an X: nothing to take off.
        Pill(label: "Paris Saint-Honoré")
            .padding(.horizontal, 16)
    }
    .frame(maxHeight: .infinity)
    .ambientBackground()
}
