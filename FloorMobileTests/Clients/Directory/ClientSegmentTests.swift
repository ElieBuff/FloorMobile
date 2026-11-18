//
//  ClientSegmentTests.swift
//  FloorMobileTests
//

import SwiftUI
import Testing
@testable import FloorMobile

/// A segment's tag shows only with both its colours readable (decision of
/// 15/11: no tag otherwise); a segment is found by its code, written the
/// same way.
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
