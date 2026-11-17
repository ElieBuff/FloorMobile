//
//  Tag.swift
//  FloorMobile
//

import SwiftUI

/// A short label in a coloured capsule — a client's segment ("VIC"), later
/// their status. It dresses whatever it is given, as the mockup draws it: in
/// the tag's text role (`AppFont.tag`, 11 pt Medium, following the reader's
/// text size), on one line, 8 pt on each side, at least 20 pt high, in
/// `foregroundColor` on a capsule of `backgroundColor`.
///
/// Any view as its content, not only a text: a status tag will put a coloured
/// dot before its word. Not `Pill`, which is a filter in white with an X to
/// take it off.
///
/// ```swift
/// Tag(backgroundColor: Color(.Base.ink), foregroundColor: Color(.Base.paper)) {
///     Text(segment)
/// }
/// ```
///
/// Swift Testing has a `Tag` of its own, the trait `.tags(_:)`: a test that
/// imports both writes `Testing.Tag` for its tags.
struct Tag<Content: View>: View {
    let backgroundColor: Color
    let foregroundColor: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .appFont(.tag)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 8)
            // 3 pt above and below the text: the mockup's 20 pt at the
            // default text size, growing with a larger one.
            .padding(.vertical, 3)
            .frame(minHeight: 20)
            .background(backgroundColor, in: .capsule)
    }
}

// MARK: - Previews

// The mockup's three segment tags, at its colours.
#Preview("Segments") {
    HStack(spacing: 6) {
        Tag(backgroundColor: Color(red: 0x14 / 255, green: 0x54 / 255, blue: 0x5F / 255),
            foregroundColor: .white) {
            Text(verbatim: "VIC")
        }
        Tag(backgroundColor: Color(red: 20 / 255, green: 84 / 255, blue: 96 / 255).opacity(0.24),
            foregroundColor: Color(red: 0x12 / 255, green: 0x3F / 255, blue: 0x48 / 255)) {
            Text(verbatim: "Connoisseur")
        }
        Tag(backgroundColor: Color(red: 20 / 255, green: 84 / 255, blue: 96 / 255).opacity(0.1),
            foregroundColor: Color(red: 0x1D / 255, green: 0x55 / 255, blue: 0x60 / 255)) {
            Text(verbatim: "Explorer")
        }
    }
    .padding()
}
