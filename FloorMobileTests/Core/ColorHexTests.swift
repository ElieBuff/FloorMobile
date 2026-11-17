//
//  ColorHexTests.swift
//  FloorMobileTests
//

import SwiftUI
import Testing
@testable import FloorMobile

/// A colour the server writes as `#RRGGBB` or `#RRGGBBAA`, its opacity last.
@Suite("Color hex")
struct ColorHexTests {

    @Test("Six digits are an opaque colour")
    func sixDigits() {
        #expect(Color.Resolved(hex: "#14545F") == Color.Resolved(
            colorSpace: .sRGB, red: Float(0x14) / 255, green: Float(0x54) / 255, blue: Float(0x5F) / 255
        ))
    }

    @Test("Eight digits carry the opacity last")
    func eightDigits() {
        #expect(Color.Resolved(hex: "#1454601A") == Color.Resolved(
            colorSpace: .sRGB, red: Float(0x14) / 255, green: Float(0x54) / 255, blue: Float(0x60) / 255,
            opacity: Float(0x1A) / 255
        ))
    }

    @Test("Lowercase reads as uppercase")
    func eitherCase() {
        #expect(Color.Resolved(hex: "#ffffff") == Color.Resolved(hex: "#FFFFFF"))
        #expect(Color.Resolved(hex: "#ffffff") == Color.Resolved(colorSpace: .sRGB, red: 1, green: 1, blue: 1))
    }

    @Test(
        "Anything else is no colour",
        arguments: ["14545F", "#12345", "#1234567", "#GGGGGG", "#+12345", "#123456789", "#", ""]
    )
    func refused(hex: String) {
        #expect(Color.Resolved(hex: hex) == nil)
    }
}
