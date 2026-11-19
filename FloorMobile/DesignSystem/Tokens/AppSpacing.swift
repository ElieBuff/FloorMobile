//
//  AppSpacing.swift
//  FloorMobile
//

import Foundation

/// Spacing values shared by several components. Only what is genuinely shared
/// belongs here — a number used in one place says more spelled out in the view
/// that uses it than hidden behind a name.
enum AppSpacing {
    /// The horizontal inset inside a card: where a row's content starts, and
    /// where the hairline between two rows stops. Five components share it, so
    /// the card's left edge is one number rather than five.
    static let cardInset: CGFloat = 18
    /// The margin between a screen's edge and its cards — the client list's
    /// mockup (14/11). Shared by `.insetGroupedList()`'s sections and what
    /// sits in line with them (a sheet's bottom action, `.bottomActionStyle()`).
    static let screenInset: CGFloat = 16
}
