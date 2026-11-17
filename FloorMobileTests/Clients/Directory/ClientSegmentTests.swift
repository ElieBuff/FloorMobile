//
//  ClientSegmentTests.swift
//  FloorMobileTests
//

import SwiftUI
import Testing
@testable import FloorMobile

/// A segment's tag shows only with both its colours readable (decision of
/// 15/11: no tag otherwise).
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
}
