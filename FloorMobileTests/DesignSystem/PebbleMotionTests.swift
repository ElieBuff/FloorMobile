//
//  PebbleMotionTests.swift
//  FloorMobileTests
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import FloorMobile

/// The intelligence pebble's outline and its motions. The instants and values
/// below are the mockup's own keyframes, written out rather than read from
/// the types' constants, so a change of motion has to be made twice.
@MainActor
@Suite("Pebble motion")
struct PebbleMotionTests {

    /// The pose `seconds` into a motion's loop.
    private func pose(of motion: PebbleMotion, at seconds: TimeInterval) -> PebblePose {
        motion.pose(at: Date(timeIntervalSinceReferenceDate: seconds))
    }

    private func isClose(_ value: CGFloat, _ expected: CGFloat, within tolerance: CGFloat = 0.001) -> Bool {
        abs(value - expected) < tolerance
    }

    /// Two outlines no eye could tell apart.
    private func isClose(_ outline: PebbleOutline, _ expected: PebbleOutline) -> Bool {
        isClose(outline.topLeading, expected.topLeading)
            && isClose(outline.topTrailing, expected.topTrailing)
            && isClose(outline.bottomTrailing, expected.bottomTrailing)
            && isClose(outline.bottomLeading, expected.bottomLeading)
            && isClose(outline.topLeadingRise, expected.topLeadingRise)
            && isClose(outline.topTrailingRise, expected.topTrailingRise)
            && isClose(outline.bottomTrailingRise, expected.bottomTrailingRise)
            && isClose(outline.bottomLeadingRise, expected.bottomLeadingRise)
    }

    /// A pose no eye could tell from the pebble at rest.
    private func isAtRest(_ pose: PebblePose) -> Bool {
        isClose(pose.outline, .rest)
            && isClose(pose.scale.width, 1) && isClose(pose.scale.height, 1)
            && isClose(pose.rotation.degrees, 0)
            && isClose(pose.offset.width, 0) && isClose(pose.offset.height, 0)
            && isClose(pose.light.scale, 1) && isClose(pose.dark.scale, 1)
            && isClose(pose.glow.opacity, 0.55)
    }

    // MARK: - Outline

    @Test("The outline reads the mockup's percentages as fractions, corner by corner")
    func outlineFromPercentages() {
        let outline = PebbleOutline([58, 42, 55, 45], [48, 60, 40, 52])
        #expect(outline == .rest)
        #expect(isClose(outline.topLeading, 0.58))
        #expect(isClose(outline.bottomLeading, 0.45))
        #expect(isClose(outline.topTrailingRise, 0.60))
        #expect(isClose(outline.bottomLeadingRise, 0.52))
    }

    @Test("The outline fills its rectangle, touching each side once")
    func outlineFillsItsRectangle() {
        let rect = CGRect(x: 10, y: 20, width: 80, height: 60)
        let path = PebbleOutline.rest.path(in: rect)
        let box = path.boundingRect
        #expect(isClose(box.minX, rect.minX, within: 0.01))
        #expect(isClose(box.maxX, rect.maxX, within: 0.01))
        #expect(isClose(box.minY, rect.minY, within: 0.01))
        #expect(isClose(box.maxY, rect.maxY, within: 0.01))
        // Where the top's two corners meet: 58 % along the width.
        #expect(path.contains(CGPoint(x: rect.minX + 0.58 * rect.width, y: rect.minY + 0.5)))
        // The rectangle's own corners are outside the curve.
        #expect(!path.contains(CGPoint(x: rect.minX + 1, y: rect.minY + 1)))
        #expect(!path.contains(CGPoint(x: rect.maxX - 1, y: rect.maxY - 1)))
    }

    @Test("Blending two outlines goes through the values in between")
    func outlineBlends() {
        var outline = PebbleOutline.rest
        var data = outline.animatableData
        data.interpolate(towards: PebbleOutline([38, 62, 36, 64], [64, 38, 62, 36]).animatableData, amount: 0.5)
        outline.animatableData = data
        #expect(isClose(outline.topLeading, 0.48))
        #expect(isClose(outline.topTrailing, 0.52))
        #expect(isClose(outline.topLeadingRise, 0.56))
        #expect(isClose(outline.bottomLeadingRise, 0.44))
    }

    // MARK: - Motions

    @Test("Three motions; the still one never leaves the rest pose")
    func stillStaysAtRest() {
        #expect(PebbleMotion.allCases == [.still, .alive, .listening])
        #expect(PebbleMotion.still.period == 0)
        #expect(pose(of: .still, at: 0) == .rest)
        #expect(pose(of: .still, at: 1.234) == .rest)
    }

    @Test("Alive loops over 3 s: it starts at rest and rests through the second half")
    func aliveRestsHalfTheLoop() {
        #expect(PebbleMotion.alive.period == 3)
        #expect(isAtRest(pose(of: .alive, at: 0)))
        #expect(isAtRest(pose(of: .alive, at: 1.5)))
        #expect(isAtRest(pose(of: .alive, at: 2.4)))
        // The loop after the first is the same.
        #expect(isAtRest(pose(of: .alive, at: 3)))
        #expect(isAtRest(pose(of: .alive, at: 4.5)))
    }

    @Test("Alive, 12 % in: turned 40°, stretched, on its second outline")
    func aliveFirstKeyframe() {
        let pose = pose(of: .alive, at: 0.36)
        #expect(isClose(pose.rotation.degrees, 40, within: 0.01))
        #expect(isClose(pose.scale.width, 1.12))
        #expect(isClose(pose.scale.height, 1.02))
        #expect(isClose(pose.outline, PebbleOutline([38, 62, 36, 64], [64, 38, 62, 36])))
        #expect(isClose(pose.offset.width, 0) && isClose(pose.offset.height, 0))
    }

    @Test("Alive: the patches of light reach their own keyframes")
    func alivePatches() {
        // 14 % in: the reflection and the dark patch.
        let early = pose(of: .alive, at: 0.42)
        #expect(isClose(early.light.offset.width, 0.46) && isClose(early.light.offset.height, 0.26))
        #expect(isClose(early.light.scale, 1.3))
        #expect(isClose(early.dark.offset.width, -0.40) && isClose(early.dark.offset.height, -0.30))
        #expect(isClose(early.dark.scale, 1.15))
        // 20 % in: the glow, at its brightest.
        let glow = pose(of: .alive, at: 0.6).glow
        #expect(isClose(glow.offset.width, -0.50) && isClose(glow.offset.height, -0.34))
        #expect(isClose(glow.opacity, 0.9))
    }

    @Test("Listening loops over 1.7 s and rests between its two bursts")
    func listeningRestsBetweenBursts() {
        #expect(PebbleMotion.listening.period == 1.7)
        #expect(isAtRest(pose(of: .listening, at: 0)))
        // 6 %: still at rest before the first burst.
        #expect(isClose(pose(of: .listening, at: 0.06 * 1.7).offset.width, 0))
        // 50 %: between the bursts, the pebble itself is still (its patches
        // have just come back).
        let between = pose(of: .listening, at: 0.5 * 1.7)
        #expect(isClose(between.outline, .rest))
        #expect(isClose(between.offset.width, 0) && isClose(between.rotation.degrees, 0))
        // 90 %: after the second burst.
        #expect(isAtRest(pose(of: .listening, at: 0.9 * 1.7)))
    }

    @Test("Listening: the first burst starts toward the leading edge, the second toward the trailing one")
    func listeningTrembles() {
        // 8 % in: 2.4 pt to the leading side and 1.1 pt down, for a pebble
        // of 79 pt, turned −2.6°.
        let first = pose(of: .listening, at: 0.08 * 1.7)
        #expect(isClose(first.offset.width, -2.4 / 79))
        #expect(isClose(first.offset.height, 1.1 / 79))
        #expect(isClose(first.rotation.degrees, -2.6, within: 0.01))
        // 10 % in: the other side.
        let back = pose(of: .listening, at: 0.10 * 1.7)
        #expect(isClose(back.offset.width, 2.4 / 79))
        #expect(isClose(back.rotation.degrees, 2.6, within: 0.01))
        // 58 % in: the second burst, smaller, toward the trailing side.
        let second = pose(of: .listening, at: 0.58 * 1.7)
        #expect(isClose(second.offset.width, 1.5 / 79))
        #expect(isClose(second.offset.height, 0.8 / 79))
        #expect(isClose(second.rotation.degrees, 1.6, within: 0.01))
    }

    @Test("Listening, 11 % in: squeezed wide on its first outline")
    func listeningSqueezes() {
        let pose = pose(of: .listening, at: 0.11 * 1.7)
        #expect(isClose(pose.scale.width, 1.13))
        #expect(isClose(pose.scale.height, 0.89))
        #expect(isClose(pose.outline, PebbleOutline([44, 56, 42, 58], [60, 44, 56, 40])))
    }

    // MARK: - Rings

    /// The rings' turns `seconds` into the listening loop.
    private func ringTurns(at seconds: TimeInterval) -> (inner: Double, outer: Double) {
        PebbleMotion.ringTurns(at: Date(timeIntervalSinceReferenceDate: seconds))
    }

    @Test("The rings rest when the listening pebble rests, and the next loop is the same")
    func ringsRestWithThePebble() {
        for fraction in [0, 0.06, 0.5, 0.9, 1.5] {
            let turns = ringTurns(at: fraction * 1.7)
            #expect(isClose(turns.inner, 0, within: 0.01), "inner ring at \(fraction)")
            #expect(isClose(turns.outer, 0, within: 0.01), "outer ring at \(fraction)")
        }
    }

    @Test("The rings swing their own ways in the bursts, at the mockup's angles")
    func ringsSwing() {
        // 11 % in: the inner ring at 9°; 10 % in: the outer at −10°.
        #expect(isClose(ringTurns(at: 0.11 * 1.7).inner, 9, within: 0.01))
        #expect(isClose(ringTurns(at: 0.10 * 1.7).outer, -10, within: 0.01))
        // 61–62 % in, the second burst: 7° and −8.5°.
        #expect(isClose(ringTurns(at: 0.62 * 1.7).inner, 7, within: 0.01))
        #expect(isClose(ringTurns(at: 0.61 * 1.7).outer, -8.5, within: 0.01))
    }
}
