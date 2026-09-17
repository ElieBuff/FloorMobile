//
//  CardStyle.swift
//  FloorMobile
//

import SwiftUI

/// The shared chrome of a card: a filled rounded surface, with an optional
/// hairline border and an optional drop shadow. One place defines "what a card
/// looks like"; each card overrides only what it needs (a different surface, a
/// border, a shadow) instead of re-spelling the whole background.
///
/// Apply with `.cardStyle(...)`. Defaults give a plain, borderless, shadowless
/// card on the standard surface. The agent card adds its light sweep on top via
/// `.agentCardStyle(...)`.
struct CardStyle: ViewModifier {
    var surface: Color = Color(.OnCanvas.surface)
    var radius: CGFloat = AppRadius.large
    var cornerStyle: RoundedCornerStyle = .continuous
    /// Hairline border, or `nil` for none.
    var border: AppBorder? = nil
    /// Drop shadow, or `nil` for none.
    var shadow: AppShadow? = nil

    func body(content: Content) -> some View {
        content
            .background(surface, in: shape)
            .overlay {
                if let border {
                    shape.strokeBorder(border.color, lineWidth: border.width)
                }
            }
            .shadow(shadow ?? .none)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: cornerStyle)
    }
}

extension View {
    /// Wraps the view in the standard card chrome (surface, rounded shape, and
    /// an optional border and shadow).
    func cardStyle(
        surface: Color = Color(.OnCanvas.surface),
        radius: CGFloat = AppRadius.large,
        cornerStyle: RoundedCornerStyle = .continuous,
        border: AppBorder? = nil,
        shadow: AppShadow? = nil
    ) -> some View {
        modifier(CardStyle(
            surface: surface,
            radius: radius,
            cornerStyle: cornerStyle,
            border: border,
            shadow: shadow
        ))
    }
}

// MARK: - Previews

#Preview("Plain / bordered / shadowed") {
    VStack(spacing: 24) {
        cardSample.cardStyle()
        cardSample.cardStyle(border: .neutral)
        cardSample.cardStyle(shadow: .high)
    }
    .padding(40)
    .background(Color.black)
}

private var cardSample: some View {
    Text("Card")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color(.OnSurface.textPrimary))
        .frame(width: 300, height: 80, alignment: .leading)
        .padding(.horizontal, 20)
}
