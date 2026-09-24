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
}
