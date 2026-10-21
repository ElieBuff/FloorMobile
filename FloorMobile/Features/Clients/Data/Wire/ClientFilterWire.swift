//
//  ClientFilterWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of a `ClientFilter`: one entry of the `clients.filters` block
/// of `GET setup` (`SetupWire`). Read-only: there is no `Request`.
nonisolated enum ClientFilterWire {
    struct Response: Decodable, Sendable {
        var id: String
        var titleKey: String
        var selection: String
        var values: [Value]
    }

    /// A value: its `ref`, and either a translation key or a label as is.
    struct Value: Decodable, Sendable {
        var ref: String
        var labelKey: String?
        var label: String?
        var parameters: [Parameter]
    }

    struct Parameter: Decodable, Sendable {
        var name: String
        var type: String
    }
}

nonisolated extension ClientFilter {
    /// `rank` is the filter's position in the block: the order the server
    /// chose.
    convenience init(wire: ClientFilterWire.Response, rank: Int) {
        self.init(
            id: wire.id,
            titleKey: wire.titleKey,
            selectionRaw: wire.selection,
            rank: rank,
            values: wire.values.map(ClientFilterValue.init(wire:))
        )
    }
}

nonisolated extension ClientFilterValue {
    init(wire: ClientFilterWire.Value) {
        self.init(
            ref: wire.ref,
            labelKey: wire.labelKey,
            label: wire.label,
            parameters: wire.parameters.map { Parameter(name: $0.name, typeRaw: $0.type) }
        )
    }
}
