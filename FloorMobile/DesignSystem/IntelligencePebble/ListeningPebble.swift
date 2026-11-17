//
//  ListeningPebble.swift
//  FloorMobile
//

import SwiftUI

/// The intelligence pebble while it listens to a voice, as the mockup draws it
/// (canvas « Tolby - App », `C-Voix-Ecoute-Anneau-Long-3L`): the pebble,
/// 80 pt, trembling (`PebbleMotion.listening`), inside two violet rings that
/// bend as it bends and swing in its bursts, each its own way
/// (`PebbleMotion.ringTurns`).
/// The rings swell and brighten with the voice — their size and opacity follow
/// its level (`SpeechTranscription.level`), where the mockup loops (decision
/// of 16/11) —, so the associate sees the microphone hears them.
///
/// Not listening — starting, stopping, stopped — the pebble moves gently
/// (`.alive`) and the rings rest, round and faint. Under Reduce Motion, or
/// with the app in the background, nothing moves: the rings only brighten
/// with the voice.
///
/// For VoiceOver, "Listening" while it listens — no line says it beside it,
/// as the mockup has none —; hidden otherwise.
///
/// ```swift
/// ListeningPebble(level: transcription.level, isListening: isListening)
/// ```
struct ListeningPebble: View {
    /// The voice's level, 0…1.
    let level: Float
    /// Whether the voice is being listened to: the pebble trembles and the
    /// rings move.
    let isListening: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// The pebble, and the box that holds the rings' swell: the mockup's.
    private static let pebbleSize: CGFloat = 80
    private static let boxSize: CGFloat = 160
    /// The rings' scale in silence and at the loudest voice, and their
    /// opacity: the mockup's extremes.
    private static let quietScale: CGFloat = 0.86
    private static let loudScale: CGFloat = 1.12
    private static let quietOpacity = 0.4

    var body: some View {
        ZStack {
            ringsView
            IntelligencePebble(size: Self.pebbleSize, motion: isListening ? .listening : .alive)
        }
        .frame(width: Self.boxSize, height: Self.boxSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Listening"))
        .accessibilityHidden(!isListening)
    }

    /// Whether the rings bend and swell.
    private var ringsMove: Bool {
        isListening && !reduceMotion && scenePhase == .active
    }

    /// The voice's level while listening, nothing otherwise.
    private var heard: CGFloat {
        isListening ? CGFloat(min(max(level, 0), 1)) : 0
    }

    private var ringsView: some View {
        TimelineView(.animation(paused: !ringsMove)) { context in
            let bend = ringsMove ? PebbleMotion.listening.pose(at: context.date).outline : .rest
            let turns = ringsMove ? PebbleMotion.ringTurns(at: context.date) : (inner: 0, outer: 0)
            ZStack {
                // The outer ring, finer and fainter, the mockup's.
                ring(diameter: 140, lineWidth: 1, opacity: 0.45, bend: bend, turn: turns.outer)
                ring(diameter: 118, lineWidth: 2, opacity: 0.8, bend: bend, turn: turns.inner)
            }
        }
        .scaleEffect(ringsMove ? Self.quietScale + (Self.loudScale - Self.quietScale) * heard : Self.quietScale)
        .opacity(Self.quietOpacity + (1 - Self.quietOpacity) * Double(heard))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: heard)
    }

    /// One ring: the circle bent as the pebble is, turned `turn` degrees.
    private func ring(
        diameter: CGFloat, lineWidth: CGFloat, opacity: Double, bend: PebbleOutline, turn: Double
    ) -> some View {
        Self.circle(bentLike: bend)
            .stroke(Color(.Pebble.mid).opacity(opacity), lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(turn))
    }

    // MARK: - Outline

    /// A circle, bent as the pebble's outline is bent away from its rest:
    /// round while the pebble rests, as the mockup's rings are, and squeezed
    /// with it in its bursts. Each side's two radii still add up to 1, which
    /// `PebbleOutline` needs.
    private static func circle(bentLike outline: PebbleOutline) -> PebbleOutline {
        let rest = PebbleOutline.rest
        var circle = PebbleOutline([50, 50, 50, 50], [50, 50, 50, 50])
        circle.topLeading += outline.topLeading - rest.topLeading
        circle.topTrailing += outline.topTrailing - rest.topTrailing
        circle.bottomTrailing += outline.bottomTrailing - rest.bottomTrailing
        circle.bottomLeading += outline.bottomLeading - rest.bottomLeading
        circle.topLeadingRise += outline.topLeadingRise - rest.topLeadingRise
        circle.topTrailingRise += outline.topTrailingRise - rest.topTrailingRise
        circle.bottomTrailingRise += outline.bottomTrailingRise - rest.bottomTrailingRise
        circle.bottomLeadingRise += outline.bottomLeadingRise - rest.bottomLeadingRise
        return circle
    }
}

// MARK: - Previews

#Preview("Quiet, speaking, not listening") {
    HStack(spacing: 0) {
        ListeningPebble(level: 0.1, isListening: true)
        ListeningPebble(level: 0.8, isListening: true)
        ListeningPebble(level: 0, isListening: false)
    }
    .scaleEffect(0.7)
    .ambientBackground()
}
