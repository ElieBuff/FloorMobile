//
//  SkeletonLines.swift
//  FloorMobile
//

import SwiftUI

/// Grey bars standing in for lines of text that are on their way — the
/// skeleton of a section whose content loads on its own, so a page shows its
/// shape before its words (a client's profile, where the AI summary can take
/// 40 s).
///
/// No text inside, unlike `.redacted(reason: .placeholder)` over made-up
/// values: nothing to invent, nothing to translate. Hidden from VoiceOver,
/// which has nothing to read until the content is in.
///
/// ```swift
/// Section {
///     SkeletonLines(widths: [1, 0.85, 0.6])
///         .listRowInsets(.cardRow)
/// }
/// ```
struct SkeletonLines: View {
    /// Each bar's width as a share of the row's — 1 the full width — one bar
    /// per line, top to bottom.
    let widths: [CGFloat]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(.OnSurface.surfaceFaint))
                        .frame(width: proxy.size.width * width)
                }
                .frame(height: 10)
            }
        }
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    List {
        Section("Summary") {
            SkeletonLines(widths: [1, 0.85, 0.6])
                .listRowInsets(.cardRow)
        }
        Section("Activity") {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonLines(widths: [0.7, 0.45])
                    .listRowInsets(.cardRow)
            }
        }
    }
    .cardList()
    .ambientBackground()
}
