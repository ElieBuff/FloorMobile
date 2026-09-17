//
//  AppBorder.swift
//  FloorMobile
//

import SwiftUI

/// Hairline border presets. Two roles today: a neutral outline that separates a
/// card from the background, and the agent card's brighter, lit rim.
struct AppBorder {
    var color: Color
    var width: CGFloat = 1

    /// The neutral outline separating a card from the background.
    static let neutral = AppBorder(color: Color(.OnCanvas.borderDefault))
    /// The agent card's bright, lit rim.
    static let bright = AppBorder(color: Color(.Base.paper).opacity(0.9))
}
