//
//  AgentCardStyle.swift
//  FloorMobile
//

import SwiftUI

/// The chrome of an "agent" card: the standard `cardStyle` (surface + rounded
/// shape) plus the agent's bright rim, a lifted shadow, and — optionally — the
/// slow `SpecularSweep` of light. It is a `cardStyle` with the agent's border
/// and shadow baked in, so agent cards stay in step with plain ones.
///
/// Apply with `.agentCardStyle(cornerRadius:sweep:)`. Set `sweep: false` for a
/// resting card that wants the look without the animated light.
struct AgentCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 24
    /// Whether the animated light band crosses the card.
    var sweep: Bool = true

    func body(content: Content) -> some View {
        content
            .cardStyle(
                radius: cornerRadius,
                border: .bright,
                shadow: .high
            )
            .specularSweep(cornerRadius: cornerRadius, isEnabled: sweep)
    }
}

extension View {
    /// Wraps the view in the agent card chrome (`cardStyle` + agent rim/shadow,
    /// and an optional light sweep).
    /// - Parameters:
    ///   - cornerRadius: the card's radius, shared by chrome and sweep.
    ///   - sweep: whether the animated light band is active.
    func agentCardStyle(cornerRadius: CGFloat = 24, sweep: Bool = true) -> some View {
        modifier(AgentCardStyle(cornerRadius: cornerRadius, sweep: sweep))
    }
}

// MARK: - Previews

#Preview("Sweep on / off") {
    VStack(spacing: 24) {
        cardSample(sweep: true)
        cardSample(sweep: false)
    }
    .padding(40)
    .background(Color.black)
}

@ViewBuilder
private func cardSample(sweep: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("BACK IN STOCK")
            .font(.system(size: 10, weight: .medium))
            .tracking(0.8)
            .foregroundStyle(Color(.OnSurface.textSecondary))
        Text("The beaded cream dress she tried in June is back in her size.")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Color(.OnSurface.textPrimary))
    }
    .padding(20)
    .frame(width: 320, alignment: .leading)
    .agentCardStyle(sweep: sweep)
}
