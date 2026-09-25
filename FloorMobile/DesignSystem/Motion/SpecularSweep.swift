//
//  SpecularSweep.swift
//  FloorMobile
//

import SwiftUI

/// A slow band of light crossing an open card, every 8 seconds.
///
/// **Why white shows on a white card.** The card is not opaque — it is white at
/// 85% over the ambient backdrop. Adding white therefore has somewhere to go:
/// the surface turns briefly more opaque and lifts off the background, exactly
/// the way light behaves on a translucent panel. Nothing dark is involved, and
/// no hue: a shade would read as something passing in front of the card, and a
/// tinted wash would read as the card being coloured rather than as light
/// crossing it — besides putting the product photo on a coloured ground.
///
/// Like `BreathingDot`, it runs off absolute time through `TimelineView` so its
/// phase survives view rebuilds, and it pauses under Reduce Motion or in the
/// background.
struct SpecularSweep: ViewModifier {
    /// Must match the card's own radius so the band is clipped to its shape.
    var cornerRadius: CGFloat
    /// When `false` the sweep never draws — for cards that want the chrome
    /// without the animated light (or to turn it off contextually).
    var isEnabled: Bool = true
    /// Seconds between two sweeps. Long enough that the card is still most of
    /// the time — the pause is what makes the crossing feel like an event.
    var period: Double = 8
    /// Seconds the band takes to cross. The rest of the period is rest.
    var travel: Double = 2.6
    /// Held back just long enough for the card to finish expanding, so the light
    /// crosses a settled card instead of racing the opening animation.
    var initialDelay: Double = 0.35

    /// When the card opened. The cycle is measured from here rather than from
    /// absolute time, so the first sweep always lands right after the card
    /// appears — otherwise the card opens onto an arbitrary point in the cycle
    /// and the first crossing can be up to a full period away.
    @State private var openedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// The bright leading edge. The card is white at 85% opacity over the
    /// ambient backdrop, so adding white genuinely reads: the surface turns
    /// briefly more opaque and lifts away from the background, which is what
    /// light actually does to a translucent panel.
    private static let highlightStrength = 0.30

    func body(content: Content) -> some View {
        content
            .overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isPaused)) { context in
                    if !isPaused, let openedAt, let progress = progress(since: openedAt, at: context.date) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(band(at: progress))
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear { openedAt = .now }
    }

    private var isPaused: Bool {
        !isEnabled || reduceMotion || scenePhase != .active
    }

    /// `nil` before the first sweep and while the card is resting between two,
    /// so nothing is drawn at all for most of the cycle.
    private func progress(since openedAt: Date, at date: Date) -> Double? {
        let sinceFirstSweep = date.timeIntervalSince(openedAt) - initialDelay
        guard sinceFirstSweep >= 0 else { return nil }

        let elapsed = sinceFirstSweep.truncatingRemainder(dividingBy: period)
        guard elapsed < travel else { return nil }
        let linear = elapsed / travel
        // Ease in and out, so the band doesn't appear and vanish at full speed.
        return (1 - cos(linear * .pi)) / 2
    }

    /// The band itself: a soft diagonal sliver that starts past the leading edge
    /// and ends past the trailing one, so it enters and leaves off-card.
    /// A single bright sliver, symmetrical, with nothing dark in it. Light
    /// only: on this backdrop ink reads far more strongly than white, so any
    /// shade trailing the highlight turns the sweep into a shadow passing in
    /// front of the card rather than light falling on it — a smudge, not a
    /// reflection.
    ///
    /// The stops sit between 0.26 and 0.74 rather than spanning the gradient end
    /// to end. A band that fades across the whole card has no edge to catch,
    /// and reads as nothing at all.
    private func band(at progress: Double) -> LinearGradient {
        let leading = -0.8 + 2.6 * progress
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0.26),
                .init(color: .white.opacity(Self.highlightStrength), location: 0.50),
                .init(color: .clear, location: 0.74)
            ],
            startPoint: UnitPoint(x: leading, y: -0.2),
            endPoint: UnitPoint(x: leading + 0.75, y: 1.2)
        )
    }
}

extension View {
    /// Adds a slow sweep of light to a card — used by `.featuredCardStyle` on
    /// an open action card.
    /// - Parameters:
    ///   - cornerRadius: the card's own radius, so the band is clipped to its
    ///     shape rather than to a square.
    ///   - isEnabled: when `false`, the sweep never draws.
    func specularSweep(cornerRadius: CGFloat, isEnabled: Bool = true) -> some View {
        modifier(SpecularSweep(cornerRadius: cornerRadius, isEnabled: isEnabled))
    }
}

// MARK: - Previews

#Preview("Sweep on a white card") {
    VStack(alignment: .leading, spacing: 8) {
        Text("BACK IN STOCK")
            .eyebrow()
            .foregroundStyle(.secondary)
        Text("The beaded cream dress she tried in June is back in her size.")
            .font(.callout.weight(.medium))
    }
    .padding(20)
    .frame(width: 320, alignment: .leading)
    .background(Color(.OnCanvas.surface), in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    .specularSweep(cornerRadius: AppRadius.large)
    .padding(40)
}
