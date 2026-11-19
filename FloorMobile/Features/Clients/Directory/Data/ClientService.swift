//
//  ClientService.swift
//  FloorMobile
//

import Foundation

/// The Clients feature's data service: everything about a client is asked of
/// the server and kept nowhere on the device (decision of 19/11) — the
/// associate's clients, a page at a time, their count, a client's profile in
/// its three parts (their details, their AI summary, their timeline), an
/// edit, the recent clients.
///
/// An `actor` though it holds no state: its isolation is what maps a page
/// off the main actor, the project's default, and its callers await it like
/// the services that write the store.
actor ClientService {

    /// One page of the associate's own clients matching `query` — or, without
    /// it, in the sort's order — and where the next page starts: `nil` once
    /// `hasMore` says there is none, whatever cursor the last page carries.
    ///
    /// Straight from the server: the list is what it finds, typos and all.
    /// See `Endpoint.searchClients` for what it sends.
    func searchClients(
        _ query: String?,
        options: ClientSearchOptions = ClientSearchOptions(),
        after cursor: String? = nil,
        using client: APIClient
    ) async throws -> (clients: [ClientItem], nextCursor: String?) {
        let page: CursorPage<ClientWire.Response> = try await client.send(
            .searchClients(query, options: options, after: cursor)
        )
        return (page.items.map(ClientItem.init(wire:)), page.hasMore ? page.nextCursor : nil)
    }

    /// How many clients `searchClients` would list for the same text and
    /// filters — the total "Sort & filter" says on its "Show" button, and the
    /// ones the clients' list says in its subtitle. Straight from the server,
    /// like a search. A refusal (409 `filters_changed`, 503 `search_timeout`)
    /// is thrown as `AppError.server(statusCode:)`, its body dropped, and a
    /// network failure as `AppError.network`, for the caller to show — or to
    /// go without the total, as both do. See `Endpoint.countClients`.
    func countClients(
        _ query: String?,
        filters: [ClientFilterChoice] = [],
        using client: APIClient
    ) async throws -> Int {
        let count: ClientWire.Count = try await client.send(.countClients(query, filters: filters))
        return count.total
    }

    /// The filters a sentence describes, as the server reads it — the sentence
    /// of "Sort & filter"'s field, read when "Your description" opens
    /// (`ClientFilterEditor.readSentence`). Straight from the server, kept
    /// nowhere: the caller shows the items, and sends back with the search
    /// the ones still there.
    /// A failure — 502, intelligence failed or did not answer within the BFF's
    /// 80 s, whatever the sentence; 400, a sentence out of bounds — is thrown
    /// as `AppError.server(statusCode:)`, a network failure as
    /// `AppError.network`. See `Endpoint.clientTextFilters`.
    func filterItems(from sentence: String, using client: APIClient) async throws -> ClientFilterItems {
        let wire: ClientFilterItemsWire.Response = try await client.send(.clientTextFilters(sentence))
        return ClientFilterItems(wire: wire)
    }

    /// Who one client is: the first part of their profile (`ClientProfile`),
    /// bounded — their purchases and messages are `timeline(id:using:)`'s.
    ///
    /// Straight from the server, like a search result: any client of the
    /// brand can be opened. So are the two other parts. A client the tenant
    /// does not have is thrown as `AppError.server(statusCode: 404)`, a
    /// network failure as `AppError.network`. See `Endpoint.clientDetails`.
    func details(id: String, using client: APIClient) async throws -> ClientItem {
        let wire: ClientWire.Response = try await client.send(.clientDetails(id: id))
        return ClientItem(wire: wire)
    }

    /// Sends what `edited` changes from `original` (`ClientWire.Request`)
    /// and returns the client as the server now has them. The signature goes
    /// with changed consents, which the server refuses without one
    /// (`AppError.server(statusCode: 422)`); not their client is a 403, a
    /// network failure `AppError.network`, and a failure writes nothing. A
    /// network failure first reads the client again: when the server holds
    /// the edit all the same, its answer only was lost, and the save stands.
    func update(
        _ edited: ClientItem,
        from original: ClientItem,
        signature: ClientSignature?,
        using client: APIClient
    ) async throws -> ClientItem {
        let body = ClientWire.Request(edited: edited, original: original, signature: signature)
        do {
            let wire: ClientWire.Response = try await client.send(.updateClient(id: original.id, body: body))
            return ClientItem(wire: wire)
        } catch let error as AppError {
            // A network failure may come after the server's write: read the client
            // again rather than send again, which would record the signature twice.
            guard case .network = error,
                  let current = try? await details(id: edited.id, using: client),
                  !edited.hasChanges(from: current) else { throw error }
            return current
        }
    }

    /// One client's AI summary, as the server has it or computes it now — a
    /// few seconds then, 40 s at most. A summary that could not be computed is
    /// thrown as `AppError.server(statusCode: 502)`, an unknown client as a
    /// 404, a network failure as `AppError.network`. See
    /// `Endpoint.clientSummary`.
    func summary(id: String, using client: APIClient) async throws -> ClientSummary {
        let wire: ClientSummaryWire.Response = try await client.send(.clientSummary(id: id))
        return ClientSummary(wire: wire)
    }

    /// One client's timeline: what is planned with them, then what happened.
    /// An unknown client is thrown as `AppError.server(statusCode: 404)`, a
    /// network failure as `AppError.network`. See `Endpoint.clientTimeline`.
    func timeline(id: String, using client: APIClient) async throws -> ClientTimeline {
        let wire: ClientTimelineWire.Response = try await client.send(.clientTimeline(id: id))
        return ClientTimeline(wire: wire)
    }

    /// The associate's recent clients, the latest view first, straight from
    /// the server: the device stores none — the client list keeps them in
    /// memory (`RecentClients`). A network failure is thrown as
    /// `AppError.network`. See `Endpoint.recentClients`.
    func recentClients(using client: APIClient) async throws -> [ClientItem] {
        let wire: ClientWire.Recents = try await client.send(.recentClients)
        return wire.items.map(ClientItem.init(wire:))
    }

    /// Records that the associate opened this client's profile, for their
    /// recent clients, which the server keeps. The list the server answers
    /// with is not read: the client list asks for the recent clients again
    /// once the profile closes (`RecentClients.refresh`). A view the server
    /// refuses (404) or that never leaves (offline, see
    /// `Endpoint.recordClientView`) throws.
    func recordView(of id: String, using client: APIClient) async throws {
        try await client.send(.recordClientView(id: id))
    }
}
