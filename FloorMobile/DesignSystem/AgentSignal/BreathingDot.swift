//
//  BreathingDot.swift
//  FloorMobile
//

import SwiftUI

/// The dot at the head of an AI action row.
///
/// It breathes continuously, because the section is meant to feel alive at all
/// times — but it deliberately avoids the thing that makes ambient motion
/// tiring, which is not the movement itself but a **countable beat**. Three
/// dots pulsing on the same 2-second period lock the eye within seconds; three
/// dots on mutually prime periods, started out of phase, are never read as a
/// rhythm at all. They are felt, not noticed.
///
/// The cadence comes from `BreathCadence`, derived from the action's id, so a
/// given row always breathes the same way and the list never re-synchronises
/// when a row is added or dismissed.
///
/// Driven by `TimelineView` rather than a `repeatForever` animation on purpose:
/// opacity is computed from absolute time, so the phase survives any view
/// rebuild (a reload, a scroll recycle, a state change in the parent) instead
/// of snapping back to the start of the cycle. It also gives us one honest
/// pause switch for both accessibility and background state.
struct BreathingDot: View {
    private let cadence: BreathCadence
    private let color: Color
    private let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Dimmest and brightest points of the breath. It never reaches zero: the
    /// dot is a permanent marker, and a marker that disappears stops being one.
    private static let dimmest = 0.32
    private static let brightest = 1.0

    /// What the dot shows when it is not breathing — mid-way through the range,
    /// so a paused list looks settled rather than caught at an extreme.
    private static let resting = 0.85

    /// - Parameters:
    ///   - seed: stable identity of the row, normally `action.id`.
    ///   - isPaused: holds the breath still. The open card sets this: once a row
    ///     is expanded it already has the reader's attention and its own sweep
    ///     of light, so a second ambient motion in the same card competes for
    ///     nothing. Breathing is what the *waiting* rows do.
    init(seed: String, isPaused: Bool = false, color: Color = Color(.Base.ink), diameter: CGFloat = 8) {
        self.cadence = BreathCadence(seed: seed)
        self.isPausedByCaller = isPaused
        self.color = color
        self.diameter = diameter
    }

    private let isPausedByCaller: Bool

    var body: some View {
        // 30 fps is well above what a 5-to-8-second fade needs, and a third of
        // the work of matching a 120 Hz display for no visible gain.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
            Circle()
                .fill(color)
                .opacity(isPaused ? Self.resting : opacity(at: context.date))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    /// Stops the clock when the caller asks, or when the animation would be
    /// unwelcome (Reduce Motion) or unseen (app backgrounded) — an infinite
    /// animation left running off-screen is the only real battery cost here.
    ///
    /// Because the wave is a function of absolute time, resuming does not
    /// restart the cycle: the dot picks the breath up wherever it would have
    /// been, so closing a card never resynchronises the list.
    private var isPaused: Bool {
        isPausedByCaller || reduceMotion || scenePhase != .active
    }

    private func opacity(at date: Date) -> Double {
        let turns = date.timeIntervalSinceReferenceDate / cadence.period + cadence.phase
        // A sine is already ease-in-ease-out at both ends, which is what makes
        // this read as breathing rather than blinking.
        let wave = (sin(turns * 2 * .pi) + 1) / 2
        return Self.dimmest + (Self.brightest - Self.dimmest) * wave
    }
}

/// How fast and from where in the cycle one dot breathes.
///
/// Both values are folded out of the row's id so they are stable for the life of
/// the action and spread evenly across the list, without any view needing to
/// know its index — passing positions down would resynchronise every dot each
/// time the list is reordered or filtered.
struct BreathCadence {
    /// Seconds for one full breath.
    let period: Double
    /// Where in that breath the dot starts, as a fraction of the period.
    let phase: Double

    /// Periods land in 5.2…8.0 s. Fast enough to be perceptible if you look for
    /// it, slow enough that peripheral vision ignores it. The 29 and 97 divisors
    /// are prime, so periods rarely coincide and, when they do, the phases don't.
    init(seed: String) {
        let folded = Self.fold(seed)
        period = 5.2 + Double(folded % 29) / 10
        phase = Double((folded / 29) % 97) / 97
    }

    /// FNV-1a rather than `hashValue`: Swift seeds string hashing per process,
    /// so `hashValue` would hand the same row a different cadence on every
    /// launch and make previews and snapshot tests non-reproducible.
    private static func fold(_ seed: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}

// MARK: - Previews

#Preview("Three dots, out of step") {
    VStack(alignment: .leading, spacing: 24) {
        ForEach(["01ARMANDINE", "01SALOME", "01INES"], id: \.self) { seed in
            HStack(spacing: 12) {
                BreathingDot(seed: seed)
                Text(seed)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f s", BreathCadence(seed: seed).period))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding(32)
}
