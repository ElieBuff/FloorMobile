//
//  PagedSearchList.swift
//  FloorMobile
//

import SwiftUI

/// What the server finds for a query and its filters, a page at a time: the
/// first once the typing pauses, the next as the end of the list comes into
/// view, a spinner while one is on its way, and the system's "No Results"
/// when the first comes back empty — in the app's list look (`.cardList()`).
///
/// The parent says how to fetch a page and how to draw a row, and decides
/// what a failure shows: the list reports it (`onFailure`) and shows nothing
/// for it on its own. The shortest query the server accepts is the parent's
/// rule too — it builds the list only for a query worth sending.
///
/// Native inside — `.task(id:)`, `List`, `ContentUnavailableView.search` —
/// and a type of its own only because two lists share this logic ("My
/// Clients" and "All Brand"): copied, it would drift apart.
///
/// ```swift
/// PagedSearchList(query: text) {
///     try await services.clients.searchBrand($0, after: $1, using: session.api)
/// } onFailure: { failure in
///     if failure.isFirstPage {
///         failedSearch = failure   // the error takes the list's place
///     } else {
///         alert = failure.alert    // the pages above it stay
///     }
/// } row: { client in
///     ClientRow(client: client)
/// }
/// ```
///
/// A search with filters passes them too —
/// `PagedSearchList(query: text, filters: filters) { … }` — and its `fetch`
/// reads them.
struct PagedSearchList<Item: Identifiable, Row: View>: View {
    /// What the server is asked for, as it is sent: the parent trims it.
    let query: String
    /// What else the search depends on — its filters, its sort: a change
    /// starts it again from its first page, as a new query does. `fetch`
    /// reads them where the parent keeps them. `nil` for a search on its
    /// text alone.
    var filters: AnyHashable? = nil
    /// One page of matches from a cursor (`nil` for the first page), and
    /// where the next one starts — `nil` once there is none. On the main
    /// actor, like a `Button`'s action: it is the parent's code, reading the
    /// parent's environment; the service it calls leaves the main actor on
    /// its own.
    let fetch: @MainActor (_ query: String, _ cursor: String?) async throws -> ([Item], String?)
    /// Told when a page fails — never when a fetch is cancelled because the
    /// search changed or the list left the screen.
    let onFailure: (PagedSearchFailure) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        QueryPages(list: self)
            // A new search — its query or its filters — a new list: nothing
            // of the last one carries over.
            .id([AnyHashable(query), filters])
    }
}

// MARK: - Failure

/// A page a `PagedSearchList` could not fetch, as its parent hears of it:
/// which query and which page, why, and how to fetch that page again.
///
/// The parent decides what it shows. For a next page, `alert`: the pages
/// above it stay, and "Try again" fetches the one that failed. For a first
/// page nothing of the search is on screen, and a closed alert would leave
/// it empty: the parent puts something in the list's place — what the
/// device holds ("My Clients"), or the error with a "Try again" that builds
/// the list afresh ("All Brand").
struct PagedSearchFailure {
    /// The query the page belongs to.
    let query: String
    /// Whether nothing of the query was on screen yet, rather than a page
    /// under those already shown.
    let isFirstPage: Bool
    /// Why — its message is the alert's.
    let error: any Error
    /// Fetches the page that failed again, the pages above it kept. Does
    /// nothing once that page is on screen — the list fetches it again on its
    /// own when it comes back on screen — or once its list is gone: a new
    /// search built another, or its parent put something in its place.
    let retry: () -> Void

    /// "Search failed" with the error's message: "Try again" fetches the page
    /// again, "Close" leaves the list as it is.
    var alert: FloorAlert {
        FloorAlert(
            kind: .error,
            title: String(localized: "Search failed"),
            message: error.localizedDescription,
            primary: AlertAction(label: String(localized: "Try again"), handler: retry),
            secondary: AlertAction(label: String(localized: "Close"), emphasis: .quiet)
        )
    }
}

// MARK: - Pages

/// The pages of one search. A view of its own, rebuilt for each search — a
/// new query or new filters (`.id` in `PagedSearchList`) — so a new search
/// starts from nothing: no page, cursor or retry of the last one carries
/// over, and a page of the last one that lands late lands in a list no
/// longer on screen.
///
/// The pages' rules are `SearchPages`', tested on their own; the view keeps
/// what is SwiftUI's. One `.task(id:)` on the request the pages ask for:
/// SwiftUI starts the fetch when it changes — the next page, or a retry —
/// cancels it when the list goes away, and starts it again every time the
/// list comes back on screen (a tab switch, a push), which `needsFetch` turns
/// down for a page already there.
private struct QueryPages<Item: Identifiable, Row: View>: View {
    /// The query, and how to fetch a page, draw a row and report a failure.
    let list: PagedSearchList<Item, Row>

    @State private var pages = SearchPages<Item>()
    /// True from the start: a new list always begins by asking for its first
    /// page — so its spinner shows at once, not after a frame of empty list.
    @State private var isLoading = true

    /// How long the typing must pause before the first page is asked for.
    /// Computed: a generic type cannot store a static property.
    private static var debounce: Duration { .milliseconds(300) }

    var body: some View {
        List {
            ForEach(pages.items) { item in
                list.row(item)
                    .listRowInsets(.cardRow)
                    .onAppearNearEnd(of: pages.items, item: item) {
                        pages.requestNextPage()
                    }
            }
            if isLoading, !pages.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .cardList()
        .overlay { placeholder }
        .task(id: pages.request) {
            await load(pages.request)
        }
    }

    /// What stands in for the list while it has nothing to show: a spinner
    /// until the first page lands, the system's "No Results" if it lands
    /// empty — and nothing after a failure, which is the parent's to show.
    @ViewBuilder
    private var placeholder: some View {
        if pages.items.isEmpty {
            if isLoading {
                ProgressView()
            } else if pages.loaded != nil {
                ContentUnavailableView.search(text: list.query)
            }
        }
    }

    // MARK: - Loading

    /// Fetches the page `request` asks for, unless it is already on screen
    /// (`SearchPages.needsFetch`), and lands it under the others. The first
    /// waits for the typing to pause: a keystroke meanwhile builds a new
    /// list, which cancels the wait — so that page is never sent.
    private func load(_ request: SearchPages<Item>.Request) async {
        guard pages.needsFetch(request) else { return }
        isLoading = true
        do {
            if request.isFirstPage {
                try await Task.sleep(for: Self.debounce)
            }
            let (page, next) = try await list.fetch(list.query, request.cursor)
            pages.land(page, next: next, for: request)
        } catch {
            // Cancelled: the search changed, or the list left the screen and
            // asks again once it is back. Not a failure either way.
            guard !Task.isCancelled else { return }
            list.onFailure(PagedSearchFailure(
                query: list.query, isFirstPage: request.isFirstPage, error: error, retry: { pages.retry() }
            ))
        }
        isLoading = false
    }
}

// MARK: - Previews

/// A made-up result, to page through without a server.
nonisolated private struct PreviewResult: Identifiable {
    let id: Int
}

// A slow server with three pages of twenty: both spinners show, the one in
// the middle before the first page, the one at the bottom before the next.
#Preview("Pages") {
    PagedSearchList(query: "mar") { _, cursor in
        try await Task.sleep(for: .seconds(1))
        let start = cursor.flatMap { Int($0) } ?? 0
        let end = start + 20
        return ((start..<end).map { PreviewResult(id: $0) }, end < 60 ? String(end) : nil)
    } onFailure: { _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}

#Preview("No results") {
    PagedSearchList(query: "zzz") { _, _ in ([], nil) } onFailure: { _ in } row: { (result: PreviewResult) in
        Text(verbatim: "Result \(result.id + 1)")
    }
    .ambientBackground()
}
