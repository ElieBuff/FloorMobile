//
//  FlowLayoutTests.swift
//  FloorMobileTests
//

import CoreGraphics
import Testing
@testable import FloorMobile

/// Which views a flow layout puts on which line.
@Suite("Flow layout")
struct FlowLayoutTests {

    @Test("Views that fit together stay on one line")
    func oneLine() {
        #expect(FlowLayout.lines(widths: [100, 100, 100], available: 320, spacing: 10) == [0..<3])
    }

    @Test("A line is full to the point: the spacing counts, the view that no longer fits goes to the next")
    func wrapsAtTheWidth() {
        #expect(FlowLayout.lines(widths: [100, 100, 100], available: 319, spacing: 10) == [0..<2, 2..<3])
        #expect(FlowLayout.lines(widths: [100, 100, 100, 100], available: 210, spacing: 10) == [0..<2, 2..<4])
    }

    @Test("A view wider than the line takes a line to itself")
    func widerThanTheLine() {
        #expect(FlowLayout.lines(widths: [50, 400, 50], available: 300, spacing: 6) == [0..<1, 1..<2, 2..<3])
        #expect(FlowLayout.lines(widths: [400], available: 300, spacing: 6) == [0..<1])
    }

    @Test("No view, no line")
    func noView() {
        #expect(FlowLayout.lines(widths: [], available: 300, spacing: 6).isEmpty)
    }
}
