//
//  ClientFilterChoiceWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientFilterChoice`: one entry of `client/search`'s
/// `filters`, a JSON list in the query. Write-only: there is no `Response`.
nonisolated enum ClientFilterChoiceWire {
    /// `{ "ref", "params" }`.
    struct Request: Encodable, Sendable {
        var ref: String
        /// `nil` rather than empty, so `JSONEncoder` drops the key for a value
        /// that asks for no parameter.
        var params: [String: String]?

        init(choice: ClientFilterChoice) {
            ref = choice.ref
            params = choice.parameters.isEmpty ? nil : choice.parameters
        }
    }
}
