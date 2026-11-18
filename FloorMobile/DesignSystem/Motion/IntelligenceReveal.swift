//
//  IntelligenceReveal.swift
//  FloorMobile
//

import SwiftUI

/// How a text Tolby's intelligence wrote comes on screen, once, as it
/// appears — wherever the app shows one (decision of 18/11), first on what
/// Tolby understood of a sentence ("Your description"). As the mockup plays
/// it (canvas « Tolby - App », `C-Voix-Compris`, `paSkel` then `paTxt`):
/// - a violet bar as wide as the text, 8 pt high, crossed by a reflection in
///   0.75 s, and gone over its last 22 %;
/// - 0.68 s in, the text itself, in 0.65 s: out of a 5 pt blur and into view
///   over the first 55 %, from a pale violet through Tolby's middle one to
///   its deep one.
///
/// It sets the text's colour — Tolby's deep violet, once revealed: what the
/// intelligence wrote reads as such. Under Reduce Motion the text shows at
/// once, in that colour.
///
/// For a text on one line, as the mockup draws it: one bar across a paragraph
/// would not stand for its lines.
///
/// Played by SwiftUI's `KeyframeAnimator`, several properties along one
/// timeline — not `TimelineView` off absolute time, which the app's loops
/// take (`SpecularSweep`): this plays once. The view rather than the
/// `keyframeAnimator` modifier, whose content closure is `@Sendable` and so
/// off the main actor.
///
/// ```swift
/// Text(filter.label)
///     .intelligenceReveal(delay: 0.22 * Double(index))
/// ```
struct IntelligenceReveal: ViewModifier {
    /// How long after the text appears its reveal starts: several texts come
    /// one after the other.
    var delay: TimeInterval = 0

    /// Whether the reveal has started — `delay` after the text appeared: it
    /// plays the keyframes, and the text stays hidden until then.
    @State private var hasStarted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The bar, the mockup's: its height, how long its reflection takes to
    /// cross it, and when it starts to fade.
    private static let barHeight: CGFloat = 8
    private static let barDuration: TimeInterval = 0.75
    private static let barFadeStart = 0.78
    /// `Pebble.mid` at 16 % and at 60 %: the mockup's `#5B3DF5` at 16 % and
    /// `#8E78FA` at 75 %, lowered as the skeleton's was on screen (17/11,
    /// `ClientFiltersDescriptionSheet`).
    private static let barPale = 0.16
    private static let barBright = 0.6
    /// The text, the mockup's: when it starts after the bar, how long it
    /// takes, the share of that it takes to come into view, and the blur it
    /// comes out of.
    private static let textDelay: TimeInterval = 0.68
    private static let textDuration: TimeInterval = 0.65
    private static let textClearShare = 0.55
    private static let blurRadius: CGFloat = 5

    func body(content: Content) -> some View {
        if reduceMotion {
            content.foregroundStyle(Color(.Pebble.deep))
        } else {
            KeyframeAnimator(initialValue: Reveal(), trigger: hasStarted) { reveal in
                content
                    .foregroundStyle(Self.tint(at: reveal.tint))
                    .opacity(hasStarted ? reveal.clarity : 0)
                    .blur(radius: Self.blurRadius * (1 - reveal.clarity))
                    .overlay {
                        Capsule()
                            .fill(Self.reflection(at: reveal.sweep, pale: Self.barPale, bright: Self.barBright))
                            .frame(height: Self.barHeight)
                            .opacity(hasStarted ? reveal.barOpacity : 0)
                            .accessibilityHidden(true)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.sweep) {
                    MoveKeyframe(0)
                    LinearKeyframe(1, duration: Self.barDuration)
                }
                KeyframeTrack(\.barOpacity) {
                    MoveKeyframe(1)
                    LinearKeyframe(1, duration: Self.barDuration * Self.barFadeStart)
                    LinearKeyframe(0, duration: Self.barDuration * (1 - Self.barFadeStart))
                }
                KeyframeTrack(\.clarity) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: Self.textDelay)
                    LinearKeyframe(1, duration: Self.textDuration * Self.textClearShare, timingCurve: .easeOut)
                }
                KeyframeTrack(\.tint) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: Self.textDelay)
                    LinearKeyframe(1, duration: Self.textDuration * Self.textClearShare, timingCurve: .easeOut)
                    LinearKeyframe(2, duration: Self.textDuration * (1 - Self.textClearShare), timingCurve: .easeOut)
                }
            }
            .task {
                // Cancelled when the text leaves the screen before its turn:
                // nothing to start then.
                guard (try? await Task.sleep(for: .seconds(delay))) != nil else { return }
                hasStarted = true
            }
        }
    }

    /// The text's colour along its reveal: `tint` 0 is Tolby's pale violet, 1
    /// its middle one, 2 its deep one — the mockup's `#B9A8FF`, `#8E78FA` and
    /// `#4B2FD6`, in the pebble's own colours.
    private static func tint(at tint: Double) -> Color {
        tint < 1
            ? Color(.Pebble.light).mix(with: Color(.Pebble.mid), by: tint)
            : Color(.Pebble.mid).mix(with: Color(.Pebble.deep), by: tint - 1)
    }

    /// The reflection that crosses a shape Tolby is about to fill — this
    /// reveal's bar, and the skeleton of "Your description" while Tolby works
    /// (`ClientFiltersDescriptionSheet`) —, as the mockup draws it: one
    /// gradient 2.2 times as wide as the shape, `Pebble.mid` at `pale` but for
    /// its middle third, which rises to `bright` — the pale turns into it,
    /// nothing is laid over. At `progress` 0 its centre sits before the
    /// shape's leading edge (−0.46): pale all over, the shape at rest; at 1,
    /// past its trailing one (2.66).
    static func reflection(at progress: Double, pale: Double, bright: Double) -> LinearGradient {
        let rest = Color(.Pebble.mid).opacity(pale)
        let centre = -0.46 + 3.12 * progress
        return LinearGradient(
            stops: [
                .init(color: rest, location: 0.34),
                .init(color: Color(.Pebble.mid).opacity(bright), location: 0.5),
                .init(color: rest, location: 0.66),
            ],
            startPoint: UnitPoint(x: centre - 1.1, y: 0.5),
            endPoint: UnitPoint(x: centre + 1.1, y: 0.5)
        )
    }
}

/// Where a text stands along its reveal: what the keyframes move. At rest it
/// is the text revealed, and the keyframes start by moving away from it — so
/// the text ends revealed wherever the animator leaves its value once they
/// are played.
private struct Reveal {
    /// How far the reflection is across the bar, from 0 to 1.
    var sweep = 1.0
    /// How visible the bar is.
    var barOpacity = 0.0
    /// How far the text is into view and out of its blur, from 0 to 1.
    var clarity = 1.0
    /// The text's colour, from 0 to 2 (`IntelligenceReveal.tint(at:)`).
    var tint = 2.0
}

extension View {
    /// Brings this text in as Tolby's intelligence writes it
    /// (`IntelligenceReveal`): a violet bar, then the text out of a blur, in
    /// Tolby's violet — `delay` after it appears.
    func intelligenceReveal(delay: TimeInterval = 0) -> some View {
        modifier(IntelligenceReveal(delay: delay))
    }
}

// MARK: - Previews

#Preview("One after the other") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(["Segment · VIC", "Opted in · WhatsApp", "Bought in the last 3 months"].enumerated()),
                id: \.offset) { index, label in
            Text(verbatim: label)
                .font(.footnote.weight(.medium))
                .intelligenceReveal(delay: 0.22 * Double(index))
        }
    }
    .padding()
}
