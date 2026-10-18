//
//  BrandClient.swift
//  FloorMobile
//

import Foundation

/// A client of the whole brand, found by a search: what the "All Brand" list
/// shows of them.
///
/// `Client`'s counterpart for the clients the device does not keep — the
/// brand runs to far more of them than a phone should hold, and most belong to
/// other stores. A plain value, so it lives only as long as the search that
/// found it. No email and no phone: the server never sends them for a client
/// that may not be this store's.
nonisolated struct BrandClient: Identifiable, Sendable, Equatable {
    let id: String
    /// "Raphaël Van den Berg", or `nil` when the server has no name.
    let displayName: String?
    let segment: String?
    /// The client's store, e.g. "Regent Street".
    let storeName: String?
    /// The associate the client is assigned to.
    let salesAssociateName: String?
}
