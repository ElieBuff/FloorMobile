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

    /// A page of the associate's own clients, 50 at most, each with their
    /// email and phone. Whose clients they are is the server's to set (their
    /// store today, from the token): the app only says `scope=mine`.
    /// Interactive: the associate waits on it, so it fails fast — without a
    /// connection, the list falls back on the device, or, with filters
    /// picked, which the device cannot apply, shows the failure
    /// (`ClientsView.showsDevice`).
    ///
    /// The text and the filters as `scopeItems` sends them; then the sort and
    /// the cursor. Without a text, the clients in the sort's order.
    static func searchClients(
        _ query: String?,
        options: ClientSearchOptions = ClientSearchOptions(),
        after cursor: String? = nil
    ) -> Endpoint {
        var items = scopeItems(query, filters: options.filters)
        if let sortBy = options.sortBy {
            items.append(URLQueryItem(name: "orderBy", value: sortBy))
        }
        if let direction = options.direction {
            items.append(URLQueryItem(name: "direction", value: direction.rawValue))
        }
        return Endpoint(path: "client/search", query: items + after(cursor), interactive: true)
    }

    /// How many clients `searchClients` would list, page after page, for the
    /// same text and filters (`scopeItems`): the total "Sort & filter" says on
    /// its "Show" button. Neither a sort nor a cursor: neither changes a
    /// total.
    ///
    /// Asked once the associate pauses in their changes, for the last state only:
    /// a request given up on runs on, server side, until its time limit. A 503
    /// (`search_timeout`) means a total too long to count: none is shown.
    /// Interactive: the associate waits on it, and a count has no list on the
    /// device to fall back on.
    static func countClients(_ query: String?, filters: [ClientFilterChoice] = []) -> Endpoint {
        Endpoint(path: "client/count", query: scopeItems(query, filters: filters), interactive: true)
    }

    /// The filters a sentence the associate typed or dictated describes
    /// (`ClientFilterItemsWire`), read by intelligence's client-query through
    /// the BFF. Interactive — the associate waits on it, so it fails at once
    /// without a connection — but with a wait of its own: an LLM takes its
    /// time, and the server's waits are chained. Intelligence gives ai_engine
    /// `AI_ENGINE_TIMEOUT_MS` (75 s, `client-query.steps.ts`), the BFF gives
    /// intelligence `TEXT_FILTERS_TIMEOUT_MS` (80 s, `intelligence.service.ts`) and
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

    /// Who one client of the brand is (`ClientWire.Response`, the card every
    /// client route sends): their contacts
    /// and consents, language, associate, store and main address — bounded,
    /// their purchases and messages are `clientTimeline`'s. One of the three
    /// parts of their profile (`ClientProfile`). Interactive: the associate
    /// waits on it, so without a connection it fails at once and the page
    /// offers to try again.
    static func clientDetails(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)", interactive: true)
    }

    /// Edits one of the associate's own clients (`ClientWire.Request`), and
    /// answers with their card as it now stands — the shape of
    /// `clientDetails`. Interactive: the associate waits on it, so without a
    /// connection it fails at once and the form offers to try again; 30 s
    /// rather than the interactive default, for a body that carries a
    /// signature and a server that writes several tables.
    static func updateClient(id: String, body: ClientWire.Request) -> Endpoint {
        Endpoint(path: "client/\(id)", method: .patch, body: body, interactive: true, timeout: 30)
    }

    /// One client's AI summary (`ClientSummaryWire`): the stored one while it
    /// is fresh, at once, else a new one, computed now. Interactive, but with
    /// a wait of its own: the BFF gives a new summary `SUMMARY_TIMEOUT_MS`
    /// (40 s, `intelligence.service.ts`) and answers 502 past it. 50 s stays
    /// above, so the app never cuts a summary the BFF is still computing —
    /// one it gives up on is finished and stored server-side anyway: raise it
    /// with them.
    static func clientSummary(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)/summary", interactive: true, timeout: 50)
    }

    /// One client's timeline (`ClientTimelineWire`): what is planned with
    /// them and what happened, every type at once — the app picks. Interactive:
    /// the associate waits on it.
    static func clientTimeline(id: String) -> Endpoint {
        Endpoint(path: "client/\(id)/timeline", interactive: true)
    }

    /// Records that the connected associate opened this client's profile: one
    /// line in the server's views journal, at the server's time. Answers with
    /// the recent clients as they now stand — `recentClients`' list, this
    /// client first —, which the app does not read: the client list asks
    /// `recentClients` again once the profile closes.
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

    /// The associate's last viewed clients, each once, the latest view first
    /// (`ClientWire.Recents`) — as many as the server keeps, its call alone.
    /// Asked each time the client list comes on screen, for its search field
    /// to show them at once (`RecentClients`).
    ///
    /// Interactive: without a connection it fails at once instead of waiting
    /// for one — the field then says so and offers to try again, where it
    /// would otherwise spin until the network came back.
    static let recentClients = Endpoint(path: "client/recent", interactive: true)

    /// `after` when there is a cursor to send, nothing otherwise.
    private static func after(_ cursor: String?) -> [URLQueryItem] {
        cursor.map { [URLQueryItem(name: "after", value: $0)] } ?? []
    }

    /// What a client search and its count share, so that a count reads what
    /// the search lists — the BFF's `clientScopeQuery`, shared by
    /// `/client/search` and `/client/count` (`client.route.ts`), to keep in
    /// step with it: `scope=mine`, the associate's own clients; `q`, matching
    /// a name, an email or a phone, the closest first, sent as given —
    /// whether a text is long enough for the server is the view's call
    /// (`ClientsView.searchMinimumLength`); and the filters picked, as a JSON
    /// list (`ClientFilterChoiceWire`).
    private static func scopeItems(_ query: String?, filters: [ClientFilterChoice]) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "scope", value: "mine")]
        if let query {
            items.append(URLQueryItem(name: "q", value: query))
        }
        if !filters.isEmpty,
           let json = URLQueryItem(name: "filters", json: filters.map(ClientFilterChoiceWire.Request.init(choice:))) {
            items.append(json)
        }
        return items
    }
}
