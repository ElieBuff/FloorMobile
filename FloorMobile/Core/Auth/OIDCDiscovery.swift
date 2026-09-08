//
//  OIDCDiscovery.swift
//  FloorMobile
//

import Foundation

/// Endpoints discovered from the issuer's OIDC configuration document,
/// so that no Zitadel URL other than the issuer is ever hardcoded.
nonisolated struct OIDCConfiguration: Decodable, Sendable {
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let endSessionEndpoint: URL

    enum CodingKeys: String, CodingKey {
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case endSessionEndpoint = "end_session_endpoint"
    }

    /// Fetches `{issuer}/.well-known/openid-configuration`.
    static func fetch(issuer: URL, session: URLSession = .shared) async throws -> OIDCConfiguration {
        let url = issuer.appending(path: ".well-known/openid-configuration")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw AppError.network(underlying: error)
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.server(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        do {
            return try JSONDecoder().decode(OIDCConfiguration.self, from: data)
        } catch {
            throw AppError.decoding(underlying: error)
        }
    }
}
