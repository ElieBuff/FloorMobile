//
//  ClientEndpoint.swift
//  FloorMobile
//

import Foundation

// MARK: - Client Endpoints

nonisolated extension Endpoint {
    /// The connected associate's store clients: all of them without a cursor,
    /// then only those changed since it. The store comes from the token, never
    /// from the request.
    ///
    /// Pass the previous page's `nextCursor` as `after` to get the next page —
    /// and, once a pass is over, its last page's `nextCursor` to get only what
    /// changed since (see `ClientService.synchronize(using:cursor:)`).
    static func clientSync(after cursor: String? = nil) -> Endpoint {
        Endpoint(path: "client/sync", query: after(cursor))
    }

    /// Every client id of the connected associate's store, all at once: what
    /// the device prunes its copy against.
    static let storeClientIDs = Endpoint(path: "client/store-ids")

    /// A page of clients, 50 at most, from one route for both lists:
    /// - `.mine`, the associate's own clients, each with their email and
    ///   phone. Whose clients they are is the server's to set (their store
    ///   today, from the token): the app only says `scope=mine`. Interactive:
    ///   the associate waits on it, so it fails fast, and the list falls back
    ///   on the device — or, with filters picked, which the device cannot
    ///   apply, shows the failure.
    /// - `.brand`, any client of the brand, as a card without contacts.
    ///
    /// The text, the scope and the filters as `scopeItems` sends them; then
    /// the sort, which goes with both scopes, and the cursor. Without a text,
    /// the clients in the sort's order.
    static func searchClients(
        _ query: String?,
        in scope: ClientSearchScope,
        options: ClientSearchOptions = ClientSearchOptions(),
        after cursor: String? = nil
    ) -> Endpoint {
        var items = scopeItems(query, in: scope, filters: options.filters)
        if let sortBy = options.sortBy {
            items.append(URLQueryItem(name: "orderBy", value: sortBy))
        }
        if let direction = options.direction {
            items.append(URLQueryItem(name: "direction", value: direction.rawValue))
        }
        return Endpoint(path: "client/search", query: items + after(cursor), interactive: scope == .mine)
    }

    /// How many clients `searchClients` would list, page after page, for the
    /// same text, scope and filters (`scopeItems`): the total of "My Clients"'
    /// filters sheet, its "Apply (n)". Neither a sort nor a cursor: neither
    /// changes a total.
    ///
    /// Asked once the associate pauses in their ticks, for the last state only:
    /// a request given up on runs on, server side, until its time limit. A 503
    /// (`search_timeout`) means a total too long to count — "Apply" without a
    /// number. Interactive in both scopes: the associate waits on it, and a
    /// count has no list on the device to fall back on.
    static func countClients(
        _ query: String?,
        in scope: ClientSearchScope,
        filters: [ClientFilterChoice] = []
    ) -> Endpoint {
        Endpoint(path: "client/count", query: scopeItems(query, in: scope, filters: filters), interactive: true)
    }

    /// The filters a sentence the associate typed or dictated describes
    /// (`ClientFilterItemsWire`), read by intelligence's client-query through
    /// the BFF. Interactive — the associate waits on it, so it fails at once
    /// without a connection — but with a wait of its own: an LLM takes its
    /// time, and the server's waits are chained. Intelligence gives ai_engine
    /// `AI_ENGINE_TIMEOUT_MS` (75 s, `client-query.steps.ts`), the BFF gives
    /// intelligence `TIMEOUT_MS` (80 s, `client-text-filters.service.ts`) and
    /// answers 502 past it. 90 s stays above both, so the app never cuts a
    /// sentence the BFF is still reading: raise it with them.
    ///
    /// The body is a dictionary rather than a request type, as for
    /// `updateTaskStatus`: one field, written in one place. A sentence outside
    /// 1 to 500 characters once trimmed is the BFF's 400
    /// (`clientTextFiltersRequestSchema`).
    static func clientTextFilters(_ sentence: String) -> Endpoint {
        Endpoint(
            path: "client/text-filters",
            method: .post,
            body: ["text": sentence],
            interactive: true,
            timeout: 90
        )
    }

    /// Everything the server holds on one client of the brand: the profile
    /// page's source (`ClientProfileWire`). Interactive: the associate waits on
    /// it, so without a connection it fails at once and the page offers to try
    /// again.
    static func clientProfile(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)", interactive: true)
    }

    /// Records that the connected associate opened this client's profile: one
    /// line in the server's views journal, at the server's time. Answers with
    /// the recent clients as they now stand — `recentClients`' list, this
    /// client first.
    ///
    /// Interactive although no one waits on its answer: the route forbids
    /// queuing a view offline — a view made without network is lost, by
    /// decision. The default session would wait for the network and send it
    /// hours later, dated by the server when it arrives; interactive, it fails
    /// at once without a connection, and after a few seconds of a silent
    /// server.
    static func recordClientView(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)/view", method: .post, interactive: true)
    }

    /// The associate's last viewed clients, each once, the latest view first —
    /// as many as the server keeps, its call alone. The device refreshes its
    /// copy (`RecentClient`) from it at launch; after a view, the answer to
    /// `recordClientView` carries the same list.
    static let recentClients = Endpoint(path: "client/recent")

    /// `after` when there is a cursor to send, nothing otherwise.
    private static func after(_ cursor: String?) -> [URLQueryItem] {
        cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
    }

    /// What a client search and its count share, so that a count reads what
    /// the search lists — the BFF's `clientScopeQuery`, shared by
    /// `/client/search` and `/client/count` (`client.route.ts`), to keep in
    /// step with it: `scope=mine` for the associate's own clients, nothing
    /// for the brand; `q`, matching a name, an email or a phone, the closest
    /// first, sent as given — whether a text is long enough for the server is
    /// the view's call (`ClientsView.searchMinimumLength`); and with `.mine`
    /// only — the server refuses them otherwise — the filters picked, as a
    /// JSON list (`ClientFilterChoiceWire`).
    private static func scopeItems(
        _ query: String?,
        in scope: ClientSearchScope,
        filters: [ClientFilterChoice]
    ) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if scope == .mine {
            items.append(URLQueryItem(name: "scope", value: "mine"))
        }
        if let query {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if scope == .mine, !filters.isEmpty,
           let json = URLQueryItem(name: "filters", json: filters.map(ClientFilterChoiceWire.Request.init(choice:))) {
            items.append(json)
        }
        return items
    }
}
