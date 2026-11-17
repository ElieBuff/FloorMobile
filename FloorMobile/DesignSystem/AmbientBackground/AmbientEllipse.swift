//
//  AmbientEllipse.swift
//  FloorMobile
//

import SwiftUI

/// One of the four blurred shapes of the app's ambient background: where it
/// sits, what it looks like, and how it breathes.
///
/// The shapes and their breath are the designer's validated background (Figma
/// frame "HOME BACKGROUND IVOIRE CLAIR (respiration)"), laid out in the
/// mockups' 393-pt-wide reference space with the origin at the screen's
/// top-left corner; `AmbientBackground` scales that space to the screen.
///
/// The four breathe on one rhythm, written once here: two breaths per loop,
/// the second shallower, each an inhale, a short hold that lets a little go, a
/// longer exhale and a rest. The blush leads and the others reach every
/// keyframe `lag` seconds later, so the light spreads instead of switching on.
/// A shape only says where it rests and where the first inhale takes it: the
/// hold and the second breath are fractions of that path.
///
/// The interpolation is SwiftUI's own (`KeyframeTimeline`), read at an absolute
/// time rather than played by `keyframeAnimator`: every screen draws its own
/// background, and a played animation would restart on each of them, out of
/// step with the screen under a sheet — the reason `BreathingDot` gives too.
/// What this type adds is the mockup's numbers, and a rhythm that can be tested
/// without a view.
struct AmbientEllipse {
    /// Width of the mockups' screen, in which the frames, blurs and breath
    /// offsets below are expressed.
    static let referenceWidth: CGFloat = 393

    /// Seconds for one loop: two breaths.
    static let period: TimeInterval = 14

    /// The parts of one breath, in seconds, as the blush plays them.
    private static let inhale: TimeInterval = 2.66
    private static let hold: TimeInterval = 0.56
    private static let exhale: TimeInterval = 2.94
    private static let pause = period / 2 - inhale - hold - exhale

    /// How far along the path from rest to peak each breath goes, and where
    /// its hold leaves it: the second breath is three quarters of the first.
    private static let firstPeak = 1.0
    private static let firstHeld = 0.97
    private static let secondPeak = 0.75
    private static let secondHeld = 0.73

    /// Figma's two easing curves. The hold and the rest are linear.
    private static let inhaleCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.4, y: 0),
        endControlPoint: UnitPoint(x: 0.3, y: 1)
    )
    private static let exhaleCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.3, y: 0.05),
        endControlPoint: UnitPoint(x: 0.3, y: 1)
    )

    /// The warm white light low on the screen.
    static let light = AmbientEllipse(
        frame: CGRect(x: -189, y: 318, width: 587, height: 561),
        color: .Ambient.light,
        blurRadius: 150,
        lag: 0.3,
        rest: Pose(scale: 0.94, opacity: 0.55),
        peak: Pose(offset: CGSize(width: 0, height: -8), scale: 1.08, opacity: 0.85),
        stillOpacity: 0.7
    )

    /// The silver grey across the top.
    static let silver = AmbientEllipse(
        frame: CGRect(x: -59, y: -219, width: 509, height: 393),
        color: .Ambient.silver,
        blurRadius: 150,
        lag: 0.1,
        rest: Pose(),
        peak: Pose(offset: CGSize(width: 0, height: -8), scale: 1.05, opacity: 0.8),
        stillOpacity: 1
    )

    /// The darker grey down the left side. It thins as the others fill, which
    /// is what makes the top of the screen brighten on the inhale.
    static let shadow = AmbientEllipse(
        frame: CGRect(x: -260, y: -111, width: 494, height: 717),
        color: .Ambient.shadow,
        blurRadius: 140,
        lag: 0.15,
        rest: Pose(opacity: 0.98),
        peak: Pose(offset: CGSize(width: -6, height: -8), scale: 1.05, opacity: 0.74),
        stillOpacity: 0.9
    )

    /// The blush on the right, the one that leads the breath.
    static let blush = AmbientEllipse(
        frame: CGRect(x: 137, y: -17, width: 401, height: 529),
        color: .Ambient.blush,
        blurRadius: 150,
        lag: 0,
        rest: Pose(offset: CGSize(width: 5, height: -6), scale: 0.92, opacity: 0.7),
        peak: Pose(offset: CGSize(width: -7, height: 9), scale: 1.12, opacity: 1),
        stillOpacity: 0.9
    )

    /// The four shapes, back to front.
    static let all = [light, silver, shadow, blush]

    /// Where the shape sits in the reference space, before it breathes.
    let frame: CGRect
    let color: ColorResource
    let blurRadius: CGFloat
    /// Seconds by which this shape follows the blush.
    let lag: TimeInterval
    /// The shape between two breaths.
    let rest: Pose
    /// The shape at the top of the first, deepest inhale.
    let peak: Pose
    /// The shape when it does not breathe (Reduce Motion): the mockup's static
    /// layer, a settled look rather than a breath caught mid-way.
    let still: Pose

    /// The loop, from rest to rest.
    private let breath: KeyframeTimeline<Pose>

    private init(
        frame: CGRect,
        color: ColorResource,
        blurRadius: CGFloat,
        lag: TimeInterval,
        rest: Pose,
        peak: Pose,
        stillOpacity: Double
    ) {
        self.frame = frame
        self.color = color
        self.blurRadius = blurRadius
        self.lag = lag
        self.rest = rest
        self.peak = peak
        self.still = Pose(opacity: stillOpacity)
        self.breath = Self.breath(from: rest, to: peak, lag: lag)
    }

    /// The shape at a given moment. Absolute time, so every background on
    /// screen shows the same instant of the same breath.
    func pose(at date: Date) -> Pose {
        breath.value(time: date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period))
    }

    /// How far a screen `width` points wide can scroll before the last shape
    /// has left it, in screen points: the lowest edge, plus two blur radii for
    /// the halo that spills past it. Beyond this the background has nothing to
    /// draw and nothing to animate.
    static func reach(forWidth width: CGFloat) -> CGFloat {
        let lowestEdge = all.map { $0.frame.maxY + 2 * $0.blurRadius }.max() ?? 0
        return lowestEdge * width / referenceWidth
    }

    /// The loop as keyframes: every shape starts inhaling at zero and lands on
    /// each keyframe `lag` seconds after the blush, so its first inhale is that
    /// much longer and its last rest that much shorter.
    private static func breath(from rest: Pose, to peak: Pose, lag: TimeInterval) -> KeyframeTimeline<Pose> {
        let stages: [(depth: Double, duration: TimeInterval, curve: UnitCurve)] = [
            (firstPeak, inhale + lag, inhaleCurve),
            (firstHeld, hold, .linear),
            (0, exhale, exhaleCurve),
            (0, pause, .linear),
            (secondPeak, inhale, inhaleCurve),
            (secondHeld, hold, .linear),
            (0, exhale, exhaleCurve),
            (0, pause - lag, .linear),
        ]
        let keyframes = stages.map { stage in
            (pose: rest.blended(toward: peak, by: stage.depth), duration: stage.duration, curve: stage.curve)
        }

        return KeyframeTimeline(initialValue: rest) {
            KeyframeTrack(\.offset) {
                for keyframe in keyframes {
                    LinearKeyframe(keyframe.pose.offset, duration: keyframe.duration, timingCurve: keyframe.curve)
                }
            }
            KeyframeTrack(\.scale) {
                for keyframe in keyframes {
                    LinearKeyframe(keyframe.pose.scale, duration: keyframe.duration, timingCurve: keyframe.curve)
                }
            }
            KeyframeTrack(\.opacity) {
                for keyframe in keyframes {
                    LinearKeyframe(keyframe.pose.opacity, duration: keyframe.duration, timingCurve: keyframe.curve)
                }
            }
        }
    }
}

extension AmbientEllipse {
    /// What the breath changes in a shape: it drifts, swells and fills. The
    /// defaults are the shape as drawn — in place, full size, opaque.
    struct Pose: Equatable {
        /// Drift from the shape's frame, in reference points.
        var offset: CGSize = .zero
        var scale: CGFloat = 1
        var opacity: Double = 1

        /// The pose `depth` of the way from this one to `other`: 0 is this
        /// pose, 1 is `other`.
        func blended(toward other: Pose, by depth: Double) -> Pose {
            Pose(
                offset: CGSize(
                    width: offset.width + (other.offset.width - offset.width) * depth,
                    height: offset.height + (other.offset.height - offset.height) * depth
                ),
                scale: scale + (other.scale - scale) * depth,
                opacity: opacity + (other.opacity - opacity) * depth
            )
        }
    }
}
