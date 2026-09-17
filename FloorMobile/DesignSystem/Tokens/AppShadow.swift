//
//  AppShadow.swift
//  FloorMobile
//

import SwiftUI

/// Drop-shadow presets, by elevation. Encapsulates the (color, radius, y)
/// triples so views ask for an elevation rather than spelling raw numbers.
struct AppShadow {
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    /// No shadow.
    static let none = AppShadow(color: .clear, radius: 0, y: 0)
    /// A card resting close to the surface.
    static let low = AppShadow(color: .black.opacity(0.08), radius: 9, y: 6)
    /// A card lifted above the surface (focused / expanded).
    static let high = AppShadow(color: .black.opacity(0.12), radius: 13, y: 10)
    /// A prominent control (a filled button) popping off its background.
    static let control = AppShadow(color: .black.opacity(0.18), radius: 9, y: 6)
}

extension View {
    /// Applies a shadow preset.
    func shadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}
