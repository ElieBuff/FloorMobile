//
//  CalendarExpansionTests.swift
//  FloorMobileTests
//

import CoreGraphics
import Testing
@testable import FloorMobile

@Suite("Calendar expansion")
struct CalendarExpansionTests {

    /// One full pull, in points: dragging exactly this far goes from the week to
    /// the month.
    private let fullPull = CalendarMetrics.expandDistance

    // MARK: - Progress

    @Test("A card with no finger on it reads as one of its two states")
    func settledProgressValues() {
        var expansion = CalendarExpansion()
        #expect(expansion.progress == 0)

        expansion.settle(toExpanded: true)
        #expect(expansion.progress == 1)
    }

    @Test("Half a pull from the week lands halfway")
    func dragTracksTheFinger() {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull / 2)
        #expect(abs(expansion.progress - 0.5) < 0.0001)
    }

    @Test("Pulling up from the month walks back down the same scale")
    func dragIsMeasuredFromTheStartingState() {
        var expansion = CalendarExpansion()
        expansion.settle(toExpanded: true)
        expansion.drag(by: -fullPull / 4)
        #expect(abs(expansion.progress - 0.75) < 0.0001)
    }

    @Test("Letting go of a drag returns to a settled state")
    func settleClearsTheDrag() {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull / 3)
        #expect(expansion.dragProgress != nil)

        expansion.settle(toExpanded: true)
        #expect(expansion.dragProgress == nil)
        #expect(expansion.progress == 1)
    }

    // MARK: - Give at both ends

    @Test("Pulling past the month yields, but never the whole way")
    func giveBeyondTheMonth() {
        var expansion = CalendarExpansion()
        expansion.settle(toExpanded: true)
        expansion.drag(by: fullPull)

        #expect(expansion.progress > 1)
        #expect(expansion.progress < 1 + CalendarMetrics.overExpand)
    }

    @Test("Pushing past the week yields much less — there is a row behind it")
    func giveBeforeTheWeek() {
        var expansion = CalendarExpansion()
        expansion.drag(by: -fullPull)

        #expect(expansion.progress < 0)
        #expect(expansion.progress > -CalendarMetrics.overCollapse)
        // The card gives twice as readily upward as it does into the last week.
        #expect(CalendarMetrics.overCollapse < CalendarMetrics.overExpand)
    }

    @Test("Only the card's height overshoots; the grid stays in its rows")
    func settledProgressHoldsInsideTheTwoStates() {
        var expansion = CalendarExpansion()
        expansion.settle(toExpanded: true)
        expansion.drag(by: fullPull)
        #expect(expansion.progress > 1)
        #expect(expansion.settledProgress == 1)

        expansion.settle(toExpanded: false)
        expansion.drag(by: -fullPull)
        #expect(expansion.progress < 0)
        #expect(expansion.settledProgress == 0)
    }

    // MARK: - What a release commits to

    @Test("Released past halfway it opens, short of it it closes", arguments: [
        (0.6 as CGFloat, true),
        (0.4 as CGFloat, false),
    ])
    func releaseFollowsTheHalfwayMark(fraction: CGFloat, opens: Bool) {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull * fraction)
        #expect(expansion.opensOnRelease(velocity: 0) == opens)
    }

    @Test("A downward flick opens the card long before halfway")
    func flickCommitsEarly() {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull * 0.2)
        // Two full pulls per second: the card is at 20% and heading for the
        // month, which is what the finger is asking for.
        #expect(expansion.opensOnRelease(velocity: 2))
        // The same position, released dead still, falls back to the week.
        #expect(!expansion.opensOnRelease(velocity: 0))
    }

    @Test("An upward flick closes it from past halfway")
    func flickBackCloses() {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull * 0.8)
        #expect(!expansion.opensOnRelease(velocity: -2))
        #expect(expansion.opensOnRelease(velocity: 0))
    }

    // MARK: - Velocity handover

    @Test("A still finger hands the spring nothing")
    func noVelocityNoHandover() {
        let expansion = CalendarExpansion()
        #expect(expansion.handoverVelocity(toExpanded: true, velocity: 0) == 0)
    }

    @Test("The handover is scaled by the travel still to cover")
    func handoverScalesWithRemainingTravel() {
        var far = CalendarExpansion()
        far.drag(by: fullPull * 0.25)

        var near = CalendarExpansion()
        near.drag(by: fullPull * 0.75)

        // Same speed, but the near card has a quarter of the distance left, so
        // it must cover it faster in animated units per second.
        let farHandover = far.handoverVelocity(toExpanded: true, velocity: 1)
        let nearHandover = near.handoverVelocity(toExpanded: true, velocity: 1)
        #expect(nearHandover > farHandover)
    }

    @Test("Released at the very limit, the handover is dropped rather than exploding")
    func handoverAtTheLimitIsDropped() {
        var expansion = CalendarExpansion()
        expansion.settle(toExpanded: true)
        // Already at the target: the remaining travel is zero, and dividing by
        // it would fire the card across the screen.
        #expect(expansion.handoverVelocity(toExpanded: true, velocity: 5) == 0)
    }

    @Test("However hard the flick, the spring never inherits more than the cap", arguments: [
        1.0 as CGFloat, 50.0, 5_000.0,
    ])
    func handoverIsCapped(velocity: CGFloat) {
        var expansion = CalendarExpansion()
        expansion.drag(by: fullPull * 0.999)
        let handover = expansion.handoverVelocity(toExpanded: true, velocity: velocity)
        #expect(handover <= 20)
        #expect(handover >= 0)
    }

    @Test("A flick against the target hands over a negative velocity, also capped")
    func handoverIsCappedDownward() {
        var expansion = CalendarExpansion()
        // Far enough from the collapsed end that there is travel left to hand a
        // velocity to. At 0.001 there is none, and the guard rightly returns
        // zero rather than kicking a spring that has already arrived.
        expansion.drag(by: fullPull * 0.5)
        let handover = expansion.handoverVelocity(toExpanded: false, velocity: -5_000)
        #expect(handover >= -20)
        #expect(handover < 0)
    }
}
