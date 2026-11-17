//
//  AmbientEllipseTests.swift
//  FloorMobileTests
//

import CoreGraphics
import Foundation
import Testing
@testable import FloorMobile

/// The breath of the ambient background's four shapes. The instants below are
/// the validated Figma frame's own keyframes, written out rather than read
/// from the type's constants, so a change of rhythm has to be made twice.
@MainActor
@Suite("Ambient ellipse")
struct AmbientEllipseTests {

    private typealias Pose = AmbientEllipse.Pose

    /// The shape `seconds` into the loop.
    private func pose(of ellipse: AmbientEllipse, at seconds: TimeInterval) -> Pose {
        ellipse.pose(at: Date(timeIntervalSinceReferenceDate: seconds))
    }

    /// Two poses no eye could tell apart: a thousandth of a scale or an
    /// opacity, a hundredth of a point.
    private func isClose(_ pose: Pose, _ expected: Pose) -> Bool {
        abs(pose.scale - expected.scale) < 0.001
            && abs(pose.opacity - expected.opacity) < 0.001
            && abs(pose.offset.width - expected.offset.width) < 0.01
            && abs(pose.offset.height - expected.offset.height) < 0.01
    }

    @Test("Four shapes, and the blush is the only one that does not wait")
    func theBlushLeads() {
        #expect(AmbientEllipse.all.count == 4)
        #expect(AmbientEllipse.blush.lag == 0)
        #expect(AmbientEllipse.silver.lag == 0.1)
        #expect(AmbientEllipse.shadow.lag == 0.15)
        #expect(AmbientEllipse.light.lag == 0.3)
    }

    @Test("Every shape rests at the start of the loop and between two breaths")
    func restsBetweenBreaths() {
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            #expect(isClose(pose(of: ellipse, at: 0), ellipse.rest), "shape \(index), start")
            #expect(isClose(pose(of: ellipse, at: 6.16 + ellipse.lag + 0.4), ellipse.rest), "shape \(index), first rest")
            #expect(isClose(pose(of: ellipse, at: 13.16 + ellipse.lag + 0.2), ellipse.rest), "shape \(index), last rest")
        }
    }

    @Test("Every shape peaks 2.66 s in, plus its own lag")
    func peaksAfterItsLag() {
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            #expect(isClose(pose(of: ellipse, at: 2.66 + ellipse.lag), ellipse.peak), "shape \(index)")
        }
    }

    @Test("When the blush peaks, the others are still filling")
    func theOthersFollow() {
        #expect(isClose(pose(of: .blush, at: 2.66), AmbientEllipse.blush.peak))
        for ellipse in [AmbientEllipse.light, .silver, .shadow] {
            // Every shape swells on the inhale, so a smaller scale is an
            // earlier point of the breath.
            #expect(pose(of: ellipse, at: 2.66).scale < ellipse.peak.scale)
        }
    }

    @Test("The hold lets a little go: 97% of the way after the first, 73% after the second")
    func holdsReleaseALittle() {
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            let firstHeld = ellipse.rest.blended(toward: ellipse.peak, by: 0.97)
            let secondHeld = ellipse.rest.blended(toward: ellipse.peak, by: 0.73)
            #expect(isClose(pose(of: ellipse, at: 3.22 + ellipse.lag), firstHeld), "shape \(index), first hold")
            #expect(isClose(pose(of: ellipse, at: 10.22 + ellipse.lag), secondHeld), "shape \(index), second hold")
        }
    }

    @Test("The second breath goes three quarters as deep as the first")
    func secondBreathIsShallower() {
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            let secondPeak = ellipse.rest.blended(toward: ellipse.peak, by: 0.75)
            #expect(isClose(pose(of: ellipse, at: 9.66 + ellipse.lag), secondPeak), "shape \(index)")
        }
    }

    @Test("The loop closes: the same pose 14 s later")
    func loops() {
        #expect(AmbientEllipse.period == 14)
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            for seconds in [1.0, 5.0, 9.0, 12.0] {
                #expect(
                    isClose(pose(of: ellipse, at: seconds + 14), pose(of: ellipse, at: seconds)),
                    "shape \(index), \(seconds) s"
                )
            }
        }
    }

    @Test("Blending goes from one pose to the other")
    func blends() {
        let rest = AmbientEllipse.blush.rest
        let peak = AmbientEllipse.blush.peak
        #expect(isClose(rest.blended(toward: peak, by: 0), rest))
        #expect(isClose(rest.blended(toward: peak, by: 1), peak))
        // Half-way between (5, −6) ×0.92 at 70% and (−7, 9) ×1.12 at 100%.
        let halfway = Pose(offset: CGSize(width: -1, height: 1.5), scale: 1.02, opacity: 0.85)
        #expect(isClose(rest.blended(toward: peak, by: 0.5), halfway))
    }

    @Test("The reach covers the lowest shape, halo included, and grows with the screen")
    func reach() {
        let reach = AmbientEllipse.reach(forWidth: 393)
        for (index, ellipse) in AmbientEllipse.all.enumerated() {
            #expect(reach >= ellipse.frame.maxY + 2 * ellipse.blurRadius, "shape \(index)")
        }
        // The light: 318 + 561 down the screen, and twice its 150-pt blur.
        #expect(reach == 1179)
        #expect(AmbientEllipse.reach(forWidth: 786) == 2 * reach)
    }
}
