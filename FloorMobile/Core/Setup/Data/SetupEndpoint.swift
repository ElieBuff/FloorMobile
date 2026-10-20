//
//  SetupEndpoint.swift
//  FloorMobile
//

import Foundation

nonisolated extension Endpoint {
    /// The app's configuration, one block per subject: the values of the
    /// pickers (`enums`) and the tenant's "My Clients" filters. Small, read
    /// whole at launch: no pagination.
    static func setup() -> Endpoint {
        Endpoint(path: "setup")
    }
}
