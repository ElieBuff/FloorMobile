//
//  IntelligencePebble.swift
//  FloorMobile
//

import SwiftUI

/// The violet pebble that marks what Tolby's intelligence does: beside a field
/// that takes a description in plain words, beside what it worked out, and,
/// larger, while it listens to a voice. One drawing at any `size`; `motion`
/// chooses how it moves (`PebbleMotion`).
///
/// The drawing is the mockup's, layer for layer (canvas « Tolby — App »): a
/// violet radial fill with a light and a dark rim inside, a dark patch, a
/// pale glow and a white reflection, cut to the pebble's outline, over a soft
/// violet shadow. Two things the mockup has are left out: its grain, which no
/// eye sees at these sizes, and the rim drawn above the patches — here it is
/// part of the fill, under them, to stay a native inner shadow.
///
/// The motion is read off absolute time through `TimelineView`, like the
/// app's other ambient motions: the loop survives a rebuild of the view, and
/// one switch stops it for Reduce Motion and for an app in the background.
///
/// Decorative: hidden from VoiceOver. What it stands for is said by the label
/// of the control beside it.
///
/// ```swift
/// IntelligencePebble(size: 16)
/// IntelligencePebble(size: 80, motion: .listening)
/// ```
struct IntelligencePebble: View {
    /// The pebble's width and height at rest, in points.
    let size: CGFloat
    let motion: PebbleMotion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(size: CGFloat, motion: PebbleMotion = .alive) {
        self.size = size
        self.motion = motion
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: isPaused)) { context in
            figure(isPaused ? .rest : motion.pose(at: context.date))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The pebble rests when it has no motion, when motion would be unwelcome
    /// (Reduce Motion) or unseen (app in the background).
    private var isPaused: Bool {
        motion == .still || reduceMotion || scenePhase != .active
    }

    /// 30 frames a second are plenty for the slow turn of `.alive`; the
    /// trembling of `.listening` changes side every 34 ms and needs the
    /// display's own rate.
    private var frameInterval: TimeInterval? {
        motion == .listening ? nil : 1.0 / 30.0
    }

    // MARK: - Drawing

    /// The mockup measures the pebble in `em`, of which it is 0.76.
    private var unit: CGFloat { size / 0.76 }

    private func figure(_ pose: PebblePose) -> some View {
        ZStack {
            pose.outline.fill(fill)
            patch(pose.dark, color: Color(.Pebble.shade).opacity(0.85), frame: Self.darkFrame)
            patch(pose.glow, color: Color(.Pebble.glow).opacity(0.95), frame: Self.glowFrame)
            patch(pose.light, gradient: Self.reflection, frame: Self.lightFrame)
        }
        .frame(width: size, height: size)
        .clipShape(pose.outline)
        .compositingGroup()
        .shadow(color: Color(.Pebble.shadow).opacity(0.38), radius: 0.04 * unit, y: 0.035 * unit)
        .scaleEffect(pose.scale)
        .rotationEffect(pose.rotation)
        .offset(x: pose.offset.width * size, y: pose.offset.height * size)
    }

    /// The violet fill, lit from the top leading corner, with the light and
    /// the dark rim inside the outline.
    private var fill: some ShapeStyle {
        RadialGradient(
            stops: [
                .init(color: Color(.Pebble.light), location: 0),
                .init(color: Color(.Pebble.mid), location: 0.34),
                .init(color: Color(.Pebble.deep), location: 0.66),
                .init(color: Color(.Pebble.dark), location: 1),
            ],
            center: UnitPoint(x: 0.26, y: 0.2),
            startRadius: 0,
            endRadius: 1.3 * size
        )
        .shadow(.inner(color: .white.opacity(0.6), radius: 0.03 * unit, x: 0.035 * unit, y: 0.045 * unit))
        .shadow(.inner(color: Color(.Pebble.rim).opacity(0.62), radius: 0.055 * unit, x: -0.055 * unit, y: -0.075 * unit))
    }

    /// Where each patch sits in the pebble's square at rest, as fractions of
    /// its size.
    private static let darkFrame = CGRect(x: 0.34, y: 0.42, width: 0.82, height: 0.76)
    private static let glowFrame = CGRect(x: 0.60, y: 0.60, width: 0.46, height: 0.42)
    private static let lightFrame = CGRect(x: 0.08, y: 0.05, width: 0.52, height: 0.44)

    /// The white reflection: nearly opaque at its heart, a quarter by the
    /// middle, nothing at its edge.
    private static let reflection = Gradient(stops: [
        .init(color: .white.opacity(0.92), location: 0),
        .init(color: .white.opacity(0.25), location: 0.55),
        .init(color: .white.opacity(0), location: 1),
    ])

    /// A patch of one color fading to nothing at its edge.
    private func patch(_ pose: PebblePose.Patch, color: Color, frame: CGRect) -> some View {
        patch(pose, gradient: Gradient(colors: [color, color.opacity(0)]), frame: frame)
    }

    /// A soft elliptical patch, placed in the pebble's square and moved as
    /// its pose says.
    private func patch(_ pose: PebblePose.Patch, gradient: Gradient, frame: CGRect) -> some View {
        let width = frame.width * size
        let height = frame.height * size
        return Rectangle()
            .fill(EllipticalGradient(gradient: gradient, center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
            .frame(width: width, height: height)
            .scaleEffect(pose.scale)
            .offset(x: pose.offset.width * width, y: pose.offset.height * height)
            .opacity(pose.opacity)
            .position(x: frame.midX * size, y: frame.midY * size)
    }
}

// MARK: - Previews

#Preview("Motions") {
    HStack(spacing: 40) {
        ForEach(PebbleMotion.allCases, id: \.self) { motion in
            IntelligencePebble(size: 80, motion: motion)
        }
    }
    .padding(40)
}

#Preview("Sizes") {
    HStack(spacing: 24) {
        IntelligencePebble(size: 16)
        IntelligencePebble(size: 32)
        IntelligencePebble(size: 80)
    }
    .padding(40)
}
