//
//  AppFont.swift
//  FloorMobile
//

import SwiftUI

/// The text roles of the app's new design, the client list's mockup first
/// (14/11): one name per role, so screens that show the same thing write it
/// the same way, and one place to change it.
///
/// A role an iOS text style matches keeps that style, which carries its size
/// and Dynamic Type: a row's detail is `.footnote` (13 pt), a tag's word
/// `.caption2` Medium (11 pt), a large tag's `.footnote` Medium (13 pt). A
/// row's title alone is numbers — 16 pt
/// Medium, tracked −0.2, the mockup's (18 pt semibold until 15/11, too
/// heavy on screen) — no iOS style being that; its size
/// scales with the reader's text size (`@ScaledMetric`, relative to
/// `.headline`).
///
/// Every role sets its line height too — 24, 18, 14 and 18 pt, the mockup's,
/// scaled like its text — rather than leave it to the font: a text style's
/// own line grows with the device's languages (3 pt taller once Thai is
/// among them, 2 pt with Arabic), and the same row was 97 pt high on one
/// device and 92 on another (measured 14/11). A modifier rather than `Font`
/// values for those reasons: a scaled size, a tracking and a line height do
/// not fit in a `Font`.
///
/// The roles of the mockup's other parts — its subtitle, its tab bar… — join
/// as their screens are done. `Eyebrow` (`.eyebrow()`), the older text role
/// of this folder, belongs here too, one day.
///
/// ```swift
/// Text(client.displayLabel).appFont(.rowTitle)
/// ```
enum AppFont {
    /// A list row's main line — a client's name: 16 pt Medium, on a 24 pt
    /// line.
    case rowTitle
    /// A list row's detail line — a client's email and phone: 13 pt, on an
    /// 18 pt line.
    case rowDetail
    /// The word in a tag (`.tagStyle()`): 11 pt Medium, on a 14 pt line.
    case tag
    /// The words in a large tag (`.tagStyle(.large)`): 13 pt Medium, on an
    /// 18 pt line.
    case tagLarge
}

extension View {
    /// Writes this text in one of the app's text roles (`AppFont`).
    func appFont(_ font: AppFont) -> some View {
        modifier(AppFontModifier(font: font))
    }
}

/// What `.appFont(_:)` applies: the role's font — an iOS text style, or, for
/// a row's title, the mockup's size at the reader's scale — and its line
/// height.
private struct AppFontModifier: ViewModifier {
    let font: AppFont

    /// A row title's size and line height, scaled like `.headline`.
    @ScaledMetric(relativeTo: .headline) var rowTitleSize: CGFloat = 16
    @ScaledMetric(relativeTo: .headline) var rowTitleLineHeight: CGFloat = 24
    /// A row detail's line height, scaled like its text style.
    @ScaledMetric(relativeTo: .footnote) var rowDetailLineHeight: CGFloat = 18
    /// A tag's line height, scaled like its text style.
    @ScaledMetric(relativeTo: .caption2) var tagLineHeight: CGFloat = 14
    /// A large tag's line height, scaled like its text style.
    @ScaledMetric(relativeTo: .footnote) var tagLargeLineHeight: CGFloat = 18

    @ViewBuilder
    func body(content: Content) -> some View {
        switch font {
        case .rowTitle:
            content
                .font(.system(size: rowTitleSize, weight: .medium))
                .tracking(-0.2)
                .lineHeight(.exact(points: rowTitleLineHeight))
        case .rowDetail:
            content
                .font(.footnote)
                .lineHeight(.exact(points: rowDetailLineHeight))
        case .tag:
            content
                .font(.caption2.weight(.medium))
                .lineHeight(.exact(points: tagLineHeight))
        case .tagLarge:
            content
                .font(.footnote.weight(.medium))
                .lineHeight(.exact(points: tagLargeLineHeight))
        }
    }
}

// MARK: - Previews

#Preview("Roles") {
    VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: "Mrs Alice Martinez").appFont(.rowTitle)
        Text(verbatim: "VIC").appFont(.tag)
        Text(verbatim: "Opted in · WhatsApp").appFont(.tagLarge)
        Text(verbatim: "alice.martinez@example.com · +33 6 12 34 56 78").appFont(.rowDetail)
    }
    .padding()
}
