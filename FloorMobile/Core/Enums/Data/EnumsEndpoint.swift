//
//  EnumsEndpoint.swift
//  FloorMobile
//

import Foundation

nonisolated extension Endpoint {
    /// The allowed values for the API's open-set fields (`task.reason`, …).
    /// Small and rarely changing: no pagination, the whole map comes at once.
    static func enums() -> Endpoint {
        Endpoint(path: "enums")
    }
}
