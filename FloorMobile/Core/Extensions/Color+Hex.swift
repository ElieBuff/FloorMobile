//
//  Color+Hex.swift
//  FloorMobile
//

import SwiftUI

nonisolated extension Color.Resolved {
    /// A colour written the way the server sends one: `#RRGGBB`, opaque, or
    /// `#RRGGBBAA`, its opacity last (`00` transparent, `FF` opaque), as CSS
    /// and Figma write it, in either case. `nil` for anything else: a colour
    /// that does not read is a colour not there. The first colours the app
    /// takes from the server: a segment's tag (`ClientSegment.tagColors`).
    ///
    /// On `Color.Resolved` rather than `Color`: it is `Equatable`, so a test
    /// compares the colour read with the one expected; a view writes
    /// `Color(resolved)`.
    ///
    /// ```swift
    /// Color.Resolved(hex: "#1454601A")   // #145460 at 10%
    /// ```
    init?(hex: String) {
        guard hex.first == "#" else { return nil }
        let digits = hex.dropFirst()
        // ASCII hex digits only: `UInt32(_:radix:)` would take a "+" too.
        guard digits.count == 6 || digits.count == 8,
              digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
              let value = UInt32(digits, radix: 16)
        else { return nil }
        // Six digits are opaque: the opacity byte is FF.
        let rgba = digits.count == 8 ? value : value << 8 | 0xFF
        func channel(_ shift: UInt32) -> Float {
            Float((rgba >> shift) & 0xFF) / 255
        }
        self.init(colorSpace: .sRGB, red: channel(24), green: channel(16), blue: channel(8), opacity: channel(0))
    }
}
