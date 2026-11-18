//
//  ClientSegmentTests.swift
//  FloorMobileTests
//

import SwiftUI
import Testing
@testable import FloorMobile

/// A segment's tag shows only with both its colours readable (decision of
/// 15/11: no tag otherwise); its dot takes its colours from the tag's; a
/// segment is found by its code, written the same way.
@Suite("Client segment")
struct ClientSegmentTests {

    private static func segment(background: String?, text: String?) -> ClientSegment {
        ClientSegment(code: "VIC", backgroundColorHex: background, textColorHex: text, rank: 0)
    }

    @Test("Both colours read: the tag's fill and text")
    func bothColours() throws {
        let colors = try #require(Self.segment(background: "#14545F", text: "#ffffff").tagColors)

        #expect(colors.background.resolve(in: EnvironmentValues()) == Color.Resolved(hex: "#14545F"))
        #expect(colors.foreground.resolve(in: EnvironmentValues()) == Color.Resolved(hex: "#ffffff"))
    }

    @Test(
        "A colour missing or unreadable: no tag",
        arguments: [
            (nil, "#ffffff"), ("#14545F", nil), (nil, nil), ("#14545F", "white"), ("teal", "#ffffff"),
        ] as [(String?, String?)]
    )
    func noTag(background: String?, text: String?) {
        #expect(Self.segment(background: background, text: text).tagColors == nil)
    }

    // MARK: - Dot

    @Test("The dot's fill is the tag's background 2.5 times as opaque, its ring the text colour at 35 %")
    func dotColoursFromTheTags() throws {
        let colors = try #require(Self.segment(background: "#1454601A", text: "#1D5560").dotColors)

        // 10 % made 25 %, the hue kept.
        let fill = colors.fill.resolve(in: EnvironmentValues())
        var background = try #require(Color.Resolved(hex: "#1454601A"))
        #expect(abs(fill.opacity - 0.255) < 0.001)
        background.opacity = fill.opacity
        #expect(fill == background)
        let ring = colors.ring.resolve(in: EnvironmentValues())
        #expect(abs(ring.opacity - 0.35) < 0.001)
    }

    @Test("An opaque background stays opaque")
    func opaqueFillStaysOpaque() throws {
        let colors = try #require(Self.segment(background: "#14545F", text: "#ffffff").dotColors)

        #expect(colors.fill.resolve(in: EnvironmentValues()).opacity == 1)
    }

    @Test("A colour missing: no dot", arguments: [(nil, "#ffffff"), ("#14545F", nil)] as [(String?, String?)])
    func noDot(background: String?, text: String?) {
        #expect(Self.segment(background: background, text: text).dotColors == nil)
    }

    // MARK: - Lookup

    @Test("A code finds the segment written the same way; none without a code, for an unknown one, in another case")
    func namedFindsBySameCode() {
        let segments = [
            ClientSegment(code: "VIP", backgroundColorHex: nil, textColorHex: nil, rank: 0),
            ClientSegment(code: "VIC", backgroundColorHex: nil, textColorHex: nil, rank: 1),
        ]

        #expect(ClientSegment.named("VIC", in: segments)?.rank == 1)
        #expect(ClientSegment.named(nil, in: segments) == nil)
        #expect(ClientSegment.named("Repeater", in: segments) == nil)
        #expect(ClientSegment.named("vic", in: segments) == nil)
    }
}
