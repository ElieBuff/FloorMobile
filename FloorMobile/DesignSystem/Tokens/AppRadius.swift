//
//  AppRadius.swift
//  FloorMobile
//

import Foundation

/// Corner-radius scale for the app's rounded shapes. One place owns the values
/// so cards, thumbnails and chips stay in step.
enum AppRadius {
    /// Icon backdrops and small chips.
    static let small: CGFloat = 12
    /// Thumbnails.
    static let medium: CGFloat = 16
    /// Cards.
    static let large: CGFloat = 24
}
