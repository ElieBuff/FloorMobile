//
//  PersonDTO.swift
//  FloorMobile
//

import Foundation

/// Shared wire fragment: a person as Floor endpoints serve it — display
/// names only. Reused by any DTO whose payload embeds a person in this
/// exact shape; an endpoint serving a richer person object gets its own
/// nested type instead of growing this one.
nonisolated struct PersonDTO: Decodable {
    var firstName: String?
    var lastName: String?
}
