//
//  ClientFilterChoiceWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientFilterChoice`: one entry of the `filters` list,
/// in JSON in the query, that `client/search` and `client/count` take.
/// Write-only: there is no `Response`.
nonisolated enum ClientFilterChoiceWire {
    /// The server's union, strict (`clientFilterChoiceSchema`): one shape or
    /// the other, never a key of both, never a `null`.
    enum Request: Encodable, Sendable {
        /// `{ "ref", "params" }`: a filter by its reference, one of the
        /// tenant's filter values (`ClientFilterValue.ref`), whose condition
        /// the server holds; `params` `nil` for a value that asks for none,
        /// so the key is dropped.
        case filterRef(ref: String, params: [String: String]?)
        /// `{ "filter": … }`: a filter whole, the condition a sentence
        /// described, sent back as it came.
        case filter(JSONValue)

        enum CodingKeys: String, CodingKey {
            case ref, params, filter
        }

        init(choice: ClientFilterChoice) {
            switch choice {
            case .value(let ref, let parameters):
                self = .filterRef(ref: ref, params: parameters.isEmpty ? nil : parameters)
            case .filter(let item):
                self = .filter(item.condition)
            }
        }

        /// By hand: Swift would nest each case under its name
        /// (`{ "filterRef": { "ref": … } }`), which the server refuses.
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .filterRef(let ref, let params):
                try container.encode(ref, forKey: .ref)
                try container.encodeIfPresent(params, forKey: .params)
            case .filter(let condition):
                try container.encode(condition, forKey: .filter)
            }
        }
    }
}
