//
//  RubberBandTests.swift
//  FloorMobileTests
//

import CoreGraphics
import Testing
@testable import FloorMobile

@Suite("RubberBand")
struct RubberBandTests {

    private let give: CGFloat = 0.12

    @Test("No pull, no give")
    func atRest() {
        #expect(RubberBand.resist(0, give: give) == 0)
        #expect(RubberBand.resist(-5, give: give) == 0)
    }

    @Test("A surface that cannot yield does not")
    func noGive() {
        #expect(RubberBand.resist(1, give: 0) == 0)
    }

    @Test("The first fraction of the pull comes through nearly intact")
    func followsTheFingerAtFirst() {
        // Ten times finer than the give: resistance has barely started, so the
        // surface should still be tracking the finger at close to full rate.
        let tiny = give / 10
        let resisted = RubberBand.resist(tiny, give: give)
        #expect(resisted > tiny * 0.5)
        #expect(resisted < tiny)
    }

    @Test("However hard it is pulled, it never yields more than it has", arguments: [
        0.5, 2.0, 20.0, 5_000.0,
    ] as [CGFloat])
    func neverExceedsTheGive(distance: CGFloat) {
        let resisted = RubberBand.resist(distance, give: give)
        #expect(resisted < give)
        #expect(resisted > 0)
    }

    @Test("Pulling further always yields further, just less and less")
    func monotonicWithDiminishingReturns() {
        let steps: [CGFloat] = [0.05, 0.1, 0.2, 0.4, 0.8]
        let resisted = steps.map { RubberBand.resist($0, give: give) }

        for (previous, next) in zip(resisted, resisted.dropFirst()) {
            #expect(next > previous)
        }

        // Diminishing returns are per point pulled, not per step: these steps
        // double each time, so the absolute gain still grows at first while the
        // *rate* falls from the very beginning.
        let rates = zip(zip(steps, steps.dropFirst()), zip(resisted, resisted.dropFirst()))
            .map { distances, yields in (yields.1 - yields.0) / (distances.1 - distances.0) }

        for (previous, next) in zip(rates, rates.dropFirst()) {
            #expect(next < previous)
        }
    }
}
