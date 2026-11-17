//
//  PebbleMotion.swift
//  FloorMobile
//

import SwiftUI

/// How the intelligence pebble moves. Each motion is a loop that starts and
/// ends on the pebble at rest (`PebblePose.rest`); the instants and values
/// are the mockup's own keyframes (canvas « Tolby — App », 15/11).
enum PebbleMotion: CaseIterable {
    /// The pebble at rest, without any motion.
    case still
    /// The pebble beside what the intelligence offers or worked out: over
    /// 3 s, it turns, stretches and changes outline for the first half, then
    /// rests for the second.
    case alive
    /// The pebble while it listens to a voice: over 1.7 s, two bursts where
    /// it trembles and is squeezed, each followed by a rest.
    case listening

    // MARK: - Keyframes

    /// A value and the instant the motion reaches it, as a fraction of the
    /// loop.
    private typealias Stop<Value> = (at: Double, value: Value)

    /// The mockup's easing between two keyframes
    /// (`cubic-bezier(.45, 0, .25, 1)`) — the pebble's, and the swing of the
    /// rings around it.
    private static let ease = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.45, y: 0),
        endControlPoint: UnitPoint(x: 0.25, y: 1)
    )

    /// The pebble's size in the mockup where the trembling is given in
    /// points: the tremble is kept in proportion at any other size.
    private static let trembleReferenceSize: CGFloat = 79

    /// The three patches of light move the same way in every motion, over
    /// the first half of the loop.
    private static let light: [Stop<PebblePose.Patch>] = [
        (0.14, patch(46, 26, scale: 1.3)),
        (0.30, patch(-10, 52, scale: 0.8)),
        (0.40, patch(8, -6, scale: 1.08)),
        (0.50, PebblePose.rest.light),
        (1, PebblePose.rest.light),
    ]
    private static let dark: [Stop<PebblePose.Patch>] = [
        (0.14, patch(-40, -30, scale: 1.15)),
        (0.30, patch(10, -46, scale: 0.88)),
        (0.40, patch(-6, 6, scale: 1.04)),
        (0.50, PebblePose.rest.dark),
        (1, PebblePose.rest.dark),
    ]
    private static let glow: [Stop<PebblePose.Patch>] = [
        (0.20, patch(-50, -34, opacity: 0.9)),
        (0.36, patch(-14, -60, opacity: 0.7)),
        (0.50, PebblePose.rest.glow),
        (1, PebblePose.rest.glow),
    ]

    private static let aliveTimeline = timeline(
        period: PebbleMotion.alive.period,
        outline: [
            (0.12, outline([38, 62, 36, 64], [64, 38, 62, 36])),
            (0.25, outline([64, 36, 46, 54], [38, 58, 42, 62])),
            (0.38, outline([46, 54, 64, 36], [58, 42, 60, 40])),
            (0.50, .rest),
            (1, .rest),
        ],
        scale: [
            (0.12, CGSize(width: 1.12, height: 1.02)),
            (0.25, CGSize(width: 0.94, height: 1.08)),
            (0.38, CGSize(width: 1.05, height: 0.97)),
            (0.50, PebblePose.rest.scale),
            (1, PebblePose.rest.scale),
        ],
        rotation: [
            (0.12, .degrees(40)),
            (0.25, .degrees(-16)),
            (0.38, .degrees(9)),
            (0.50, .zero),
            (1, .zero),
        ],
        rotationCurve: ease,
        offset: [(1, .zero)]
    )

    private static let listeningTimeline: KeyframeTimeline<PebblePose> = {
        // Two bursts of trembling, 2 % of the loop apart: side to side, a
        // little less far each time. The first starts toward the leading
        // edge, the second toward the trailing one.
        let firstBurst: [(x: CGFloat, y: CGFloat)] = [
            (2.4, 1.1), (2.4, 1.1), (2.3, 1.0), (2.3, 1.0), (2.2, 1.0), (2.2, 1.0), (2.2, 1.0), (2.1, 1.0), (2.1, 0.9), (2.0, 0.9),
            (2.0, 0.9), (2.0, 0.9), (1.9, 0.9), (1.9, 0.8), (1.8, 0.8), (1.8, 0.8), (1.8, 0.8), (1.7, 0.8), (1.7, 0.8),
        ]
        let secondBurst: [(x: CGFloat, y: CGFloat)] = [
            (1.5, 0.8), (1.5, 0.7), (1.4, 0.7), (1.4, 0.7), (1.3, 0.7), (1.3, 0.7), (1.3, 0.6), (1.2, 0.6), (1.2, 0.6), (1.1, 0.6),
            (1.1, 0.6), (1.1, 0.5), (1.0, 0.5),
        ]
        var offset: [Stop<CGSize>] = [(0.06, .zero)]
        var rotation: [Stop<Angle>] = [(0.06, .zero)]
        for (index, reach) in firstBurst.enumerated() {
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let instant = 0.08 + 0.02 * Double(index)
            offset.append((instant, CGSize(width: side * reach.x / trembleReferenceSize, height: -side * reach.y / trembleReferenceSize)))
            rotation.append((instant, .degrees(side * 2.6)))
        }
        offset += [(0.46, .zero), (0.56, .zero)]
        rotation += [(0.46, .zero), (0.56, .zero)]
        for (index, reach) in secondBurst.enumerated() {
            let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let instant = 0.58 + 0.02 * Double(index)
            offset.append((instant, CGSize(width: side * reach.x / trembleReferenceSize, height: side * reach.y / trembleReferenceSize)))
            rotation.append((instant, .degrees(side * 1.6)))
        }
        offset += [(0.84, .zero), (1, .zero)]
        rotation += [(0.84, .zero), (1, .zero)]

        // The squeeze of each burst: an outline and a stretch per instant.
        let squeeze: [(at: Double, outline: PebbleOutline, width: CGFloat, height: CGFloat)] = [
            (0.06, .rest, 1, 1),
            (0.11, outline([44, 56, 42, 58], [60, 44, 56, 40]), 1.13, 0.89),
            (0.17, outline([60, 40, 58, 42], [42, 60, 40, 58]), 0.9, 1.11),
            (0.23, outline([42, 58, 46, 54], [58, 42, 60, 40]), 1.15, 0.87),
            (0.29, outline([58, 42, 60, 40], [44, 58, 42, 56]), 0.92, 1.09),
            (0.35, outline([46, 54, 44, 56], [56, 46, 54, 44]), 1.1, 0.92),
            (0.41, outline([56, 44, 54, 46], [48, 56, 44, 52]), 0.96, 1.05),
            (0.46, .rest, 1, 1),
            (0.56, .rest, 1, 1),
            (0.62, outline([46, 54, 44, 56], [58, 44, 56, 42]), 1.09, 0.92),
            (0.68, outline([58, 42, 56, 44], [44, 58, 42, 56]), 0.93, 1.08),
            (0.74, outline([48, 52, 46, 54], [54, 46, 54, 46]), 1.06, 0.95),
            (0.79, outline([56, 44, 54, 46], [48, 58, 42, 52]), 0.98, 1.03),
            (0.84, .rest, 1, 1),
            (1, .rest, 1, 1),
        ]

        return timeline(
            period: PebbleMotion.listening.period,
            outline: squeeze.map { ($0.at, $0.outline) },
            scale: squeeze.map { ($0.at, CGSize(width: $0.width, height: $0.height)) },
            rotation: rotation,
            rotationCurve: .linear,
            offset: offset
        )
    }()

    /// The turn of each ring around the listening pebble over its loop, in
    /// degrees (`ringTurns`): the mockup's keyframes (`vxWob`, `vxWob2`), at
    /// rest at the loop's own rests.
    private static let innerRingTimeline = turnTimeline([
        (0.06, 0), (0.11, 9), (0.17, -2.8), (0.23, 10), (0.29, -3.5), (0.35, 8), (0.41, -2.1),
        (0.46, 0), (0.56, 0), (0.62, 7), (0.68, -2.4), (0.74, 6), (0.79, -1.8), (0.84, 0), (1, 0),
    ])
    private static let outerRingTimeline = turnTimeline([
        (0.06, 0), (0.10, -10), (0.16, 3.5), (0.22, -7.5), (0.28, 2.1), (0.34, -9), (0.40, 3.9),
        (0.46, 0), (0.56, 0), (0.61, -8.5), (0.67, 3.1), (0.73, -7), (0.80, 2.1), (0.84, 0), (1, 0),
    ])

    // MARK: - Motion

    /// The length of one loop, or zero for a pebble that does not move.
    var period: TimeInterval {
        switch self {
        case .still: 0
        case .alive: 3
        case .listening: 1.7
        }
    }

    /// The pebble's pose at `date`. Read off absolute time, so the loop
    /// carries on where it should be after any rebuild of the view.
    func pose(at date: Date) -> PebblePose {
        guard let timeline else { return .rest }
        return timeline.value(time: loopTime(at: date))
    }

    /// How far the two rings around the listening pebble (`ListeningPebble`)
    /// are turned at `date`, in degrees: still while the pebble rests,
    /// swinging in its two bursts — the inner ring one way, the outer the
    /// other. On the listening loop, so the rings keep in step with the
    /// pebble.
    static func ringTurns(at date: Date) -> (inner: Double, outer: Double) {
        let time = PebbleMotion.listening.loopTime(at: date)
        return (innerRingTimeline.value(time: time), outerRingTimeline.value(time: time))
    }

    /// Where `date` falls in the loop.
    private func loopTime(at date: Date) -> TimeInterval {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
    }

    private var timeline: KeyframeTimeline<PebblePose>? {
        switch self {
        case .still: nil
        case .alive: Self.aliveTimeline
        case .listening: Self.listeningTimeline
        }
    }

    // MARK: - Building the keyframes

    private static func outline(_ horizontal: [CGFloat], _ vertical: [CGFloat]) -> PebbleOutline {
        PebbleOutline(horizontal, vertical)
    }

    private static func patch(_ x: CGFloat, _ y: CGFloat, scale: CGFloat = 1, opacity: Double = 1) -> PebblePose.Patch {
        PebblePose.Patch(offset: CGSize(width: x / 100, height: y / 100), scale: scale, opacity: opacity)
    }

    /// One ring's turn over the listening loop through `stops`, eased as the
    /// pebble is.
    private static func turnTimeline(_ stops: [Stop<Double>]) -> KeyframeTimeline<Double> {
        let keyframes = steps(stops, period: PebbleMotion.listening.period)
        return KeyframeTimeline(initialValue: 0) {
            KeyframeTrack {
                for step in keyframes {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
        }
    }

    /// Each stop as a keyframe of a loop of `period` seconds: its value and
    /// the time since the stop before it.
    private static func steps<Value>(
        _ stops: [Stop<Value>], period: TimeInterval
    ) -> [(value: Value, duration: TimeInterval)] {
        var previous = 0.0
        return stops.map { stop in
            defer { previous = stop.at }
            return (stop.value, (stop.at - previous) * period)
        }
    }

    /// One loop of `period` seconds through the given stops, each track
    /// starting from the pebble at rest. The outline, the stretch and the
    /// patches ease between two stops; the offset goes straight, and the
    /// rotation as `rotationCurve` says (it is the pebble's own turn in one
    /// motion, its trembling in the other).
    private static func timeline(
        period: TimeInterval,
        outline: [Stop<PebbleOutline>],
        scale: [Stop<CGSize>],
        rotation: [Stop<Angle>],
        rotationCurve: UnitCurve,
        offset: [Stop<CGSize>]
    ) -> KeyframeTimeline<PebblePose> {
        let outline = steps(outline, period: period)
        let scale = steps(scale, period: period)
        let rotation = steps(rotation, period: period)
        let offset = steps(offset, period: period)
        let light = steps(light, period: period)
        let dark = steps(dark, period: period)
        let glow = steps(glow, period: period)

        return KeyframeTimeline(initialValue: PebblePose.rest) {
            KeyframeTrack(\.outline) {
                for step in outline {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
            KeyframeTrack(\.scale) {
                for step in scale {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
            KeyframeTrack(\.rotation) {
                for step in rotation {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: rotationCurve)
                }
            }
            KeyframeTrack(\.offset) {
                for step in offset {
                    LinearKeyframe(step.value, duration: step.duration)
                }
            }
            KeyframeTrack(\.light) {
                for step in light {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
            KeyframeTrack(\.dark) {
                for step in dark {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
            KeyframeTrack(\.glow) {
                for step in glow {
                    LinearKeyframe(step.value, duration: step.duration, timingCurve: ease)
                }
            }
        }
    }
}
