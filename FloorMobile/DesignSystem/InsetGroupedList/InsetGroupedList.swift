//
//  InsetGroupedList.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// The app's list look: an inset-grouped list — each section a rounded
    /// group, `AppSpacing.screenInset` from the screen's edges (the client
    /// list's mockup) — and no system background, so the screen's
    /// `ambientBackground()` shows through. Apply to a `List`. The groups'
    /// corners are the system's: a list section has no API for them.
    ///
    /// The groups' fill and their separators' tint are not set here: on a
    /// `List`, iOS ignores `listRowBackground` and `listRowSeparatorTint`
    /// (measured 14/11), which only act on the rows. `.insetGroupedRow()` sets
    /// them on a row; a list whose rows go without keeps the system's white
    /// rows and grey hairlines.
    func insetGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .listSectionMargins(.horizontal, AppSpacing.screenInset)
            .scrollContentBackground(.hidden)
    }

    /// A row of an `.insetGroupedList()` in the client list's look: its
    /// insets, its hairline stopping at its content, the group's fill and the
    /// hairline's tint. Apply to each row — `PagedSearchList`'s, the recent
    /// clients'. A function rather than a `ViewModifier`, like
    /// `insetGroupedList()`: four modifiers in a row, with no state of their
    /// own.
    func insetGroupedRow() -> some View {
        self
            .listRowInsets(.insetGroupedRowInsets)
            // The hairline stops at the row's content, 18 pt from the group's
            // right edge as from its left: inset, not full-bleed —
            // `CardDivider`'s rule.
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
            // The group's fill and its hairline's tint, on the rows: set on
            // the `List`, iOS ignores both. A row with a fill of its own no
            // longer greys while pressed — accepted (decision of 15/11),
            // white being too stark under the text.
            .listRowBackground(Color(.OnCanvas.surface))
            .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
    }
}
