//
//  TagStyle.swift
//  FloorMobile
//

import SwiftUI

/// How big a tag is (`View.tagStyle`): the two sizes the mockups draw, each
/// with its height, its text role and its margins — which go together, so a
/// size is a name and not a height.
///
/// Not iOS's `ControlSize`, which the app's buttons take: it has five cases
/// where two tags are drawn — a `.tagStyle(.small)` would quietly draw the
/// regular one —, and a tag is no control. Here, only a size that exists can
/// be asked for.
enum TagSize {
    /// At least 20 pt high, 11 pt Medium (`AppFont.tag`), 8 pt on each side:
    /// a client's segment in a list row.
    case regular
    /// At least 34 pt high, 13 pt Medium (`AppFont.tagLarge`), 14 pt on each
    /// side: what Tolby understood of a sentence, in "Your description".
    case large

    /// The role its text is written in.
    fileprivate var font: AppFont {
        switch self {
        case .regular: .tag
        case .large: .tagLarge
        }
    }

    /// Between the capsule's ends and its content.
    fileprivate var horizontalPadding: CGFloat {
        switch self {
        case .regular: 8
        case .large: 14
        }
    }

    /// Above and below the text's line: with it, the mockup's height at the
    /// default text size — 3 + 14 + 3, 8 + 18 + 8 —, growing with a larger
    /// one.
    fileprivate var verticalPadding: CGFloat {
        switch self {
        case .regular: 3
        case .large: 8
        }
    }

    /// The least the capsule is high, the mockup's.
    fileprivate var minHeight: CGFloat {
        switch self {
        case .regular: 20
        case .large: 34
        }
    }
}

extension View {
    /// Dresses this view as a tag: a short label in a capsule — a client's
    /// segment ("VIC"), what Tolby understood of a sentence. As the mockups
    /// draw it: in the size's text role (`TagSize`), on one line — cut with
    /// an ellipsis past the room it is given —, in `foreground`, on a capsule
    /// of `background`, outlined by `border` if it has one.
    ///
    /// A modifier rather than a component (decision of 18/11): a tag has no
    /// state and no structure, only a look, and the caller keeps its content
    /// — a text, a coloured dot before a word — and what it lays between that
    /// content and the capsule, as "Your description" does to bring its tags
    /// in. An extension rather than a `ViewModifier`, as `.bottomActionStyle()`:
    /// a chain of modifiers with no state of its own. Named `tagStyle`:
    /// `tag(_:)` is SwiftUI's, for a `Picker`'s rows.
    ///
    /// A foreground the content sets itself wins over `foreground`. Not
    /// `Pill`, a 36 pt capsule to pick or to take off: a tag only shows.
    ///
    /// ```swift
    /// Text(segment.code)
    ///     .tagStyle(background: colors.background, foreground: colors.foreground)
    /// ```
    func tagStyle(
        _ size: TagSize = .regular,
        background: Color = .clear,
        foreground: Color,
        border: AppBorder? = nil
    ) -> some View {
        appFont(size.font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .background(background, in: .capsule)
            .overlay {
                if let border {
                    Capsule().strokeBorder(border.color, style: border.strokeStyle)
                }
            }
    }
}

// MARK: - Previews

// The mockup's three segment tags, at its colours.
#Preview("Segments") {
    HStack(spacing: 6) {
        Text(verbatim: "VIC")
            .tagStyle(
                background: Color(red: 0x14 / 255, green: 0x54 / 255, blue: 0x5F / 255),
                foreground: .white
            )
        Text(verbatim: "Connoisseur")
            .tagStyle(
                background: Color(red: 20 / 255, green: 84 / 255, blue: 96 / 255).opacity(0.24),
                foreground: Color(red: 0x12 / 255, green: 0x3F / 255, blue: 0x48 / 255)
            )
        Text(verbatim: "Explorer")
            .tagStyle(
                background: Color(red: 20 / 255, green: 84 / 255, blue: 96 / 255).opacity(0.1),
                foreground: Color(red: 0x1D / 255, green: 0x55 / 255, blue: 0x60 / 255)
            )
    }
    .padding()
}

#Preview("Sizes, a dashed border") {
    VStack(alignment: .leading, spacing: 12) {
        Text(verbatim: "Regular")
            .tagStyle(background: Color(.OnSurface.surfaceFaint), foreground: Color(.OnSurface.textPrimary))
        Text(verbatim: "Large")
            .tagStyle(.large, background: Color(.OnSurface.surfaceFaint), foreground: Color(.OnSurface.textPrimary))
        // No fill, a dashed outline: what Tolby did not understand.
        Text(verbatim: "“who like red”")
            .tagStyle(
                .large,
                foreground: Color(.OnSurface.textSecondary),
                border: AppBorder(color: Color(.OnSurface.textSecondary), dash: [3, 3])
            )
    }
    .padding()
}
