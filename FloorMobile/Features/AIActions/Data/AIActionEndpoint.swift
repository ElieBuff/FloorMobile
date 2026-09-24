//
//  AIActionEndpoint.swift
//  FloorMobile
//

import Foundation

// MARK: - AI Actions Endpoints

nonisolated extension Endpoint {
    /// The connected sales associate's actionable AI actions: live status
    /// (PENDING/SHOWN) and currently displayable. The BFF hardcodes all
    /// filtering server-side — this endpoint backs exactly one mobile screen
    /// and takes no parameters.
    ///
    /// - Returns: An endpoint that responds with `[AIActionDTO]`.
    static func getPendingActions() -> Endpoint {
        Endpoint(path: "ai-action/pending")
    }
}
