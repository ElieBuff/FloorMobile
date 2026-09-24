//
//  CardDivider.swift
//  FloorMobile
//

import SwiftUI

/// The hairline between two rows sharing one card.
///
/// Inset rather than full-bleed: a line that ran to the card's edges would read
/// as cutting the card in two, where an inset one reads as separating the rows
/// inside it.
///
/// Not SwiftUI's `Divider`, which draws a system separator whose colour and
/// insets belong to the platform rather than to this palette.
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.OnSurface.borderSubtle))
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.cardInset)
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 0) {
        Text("First row").frame(height: 60)
        CardDivider()
        Text("Second row").frame(height: 60)
    }
    .frame(width: 361)
    .cardStyle()
    .padding(40)
    .background(Color(.Base.canvas))
}
