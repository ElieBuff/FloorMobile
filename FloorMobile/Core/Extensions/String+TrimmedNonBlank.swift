//
//  String+TrimmedNonBlank.swift
//  FloorMobile
//

import Foundation

nonisolated extension String {
    /// The text without its surrounding spaces and line breaks, or `nil` when
    /// nothing is left — a field typed blank is a field not filled in, never
    /// an empty string to send. Through optional chaining for an optional
    /// field: `client.firstName?.trimmedNonBlank`.
    var trimmedNonBlank: String? {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
