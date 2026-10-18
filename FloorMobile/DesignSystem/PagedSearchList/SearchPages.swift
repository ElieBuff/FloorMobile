//
//  SearchPages.swift
//  FloorMobile
//

/// The pages of one server search, as `PagedSearchList` shows them: what is
/// on screen, which page to ask for next, and what a failed page asks for
/// again.
///
/// A value type rather than `@State` scattered in the view, for the reason
/// `CalendarExpansion` is one: the rules are delicate — a page lands once,
/// whichever try fetched it; the next page is asked for once, and never after
/// the last; a retry asks again for exactly the page that failed; a client the
/// server repeats on the next page is shown once — and none of them can be
/// checked by scrolling a list by hand. `SearchPagesTests` checks them instead.
nonisolated struct SearchPages<Item: Identifiable> {
    /// What is on screen, in the server's order.
    private(set) var items: [Item] = []
    /// The page to fetch next, or again.
    private(set) var request = Request()
    /// The request whose page landed last — `nil` until the first does: what
    /// tells a first page that came back empty from one still on its way, or
    /// failed.
    private(set) var loaded: Request?
    /// Where the next page starts — `nil` before the first lands, and once
    /// there is none.
    private var nextCursor: String?

    /// What a page is asked for with: where it starts, and how many tries.
    struct Request: Equatable {
        /// The page to fetch: `nil` for the first.
        var cursor: String?
        /// Bumped by `retry()`: the request changes without changing what it
        /// asks for.
        var retries = 0

        /// Whether nothing of the search is on screen before this page.
        var isFirstPage: Bool { cursor == nil }
    }

    /// Whether `request`'s page is still to fetch — not once it is on screen,
    /// whichever try fetched it: back on screen, the list asks again for the
    /// page it shows, and a "Try again" left on screen can come after that
    /// page landed.
    func needsFetch(_ request: Request) -> Bool {
        guard let loaded else { return true }
        return loaded.cursor != request.cursor
    }

    /// Puts `page`, fetched for `request`, under what is on screen, and keeps
    /// where the next page starts. A client already on screen is left out:
    /// between two pages, a refresh of the server's name dictionary can
    /// repeat a few (`client-search.service.ts`).
    mutating func land(_ page: [Item], next: String?, for request: Request) {
        let shown = Set(items.map(\.id))
        items += page.filter { !shown.contains($0.id) }
        nextCursor = next
        loaded = request
    }

    /// Asks for the page after the last one — once: nothing if there is none
    /// left, or if it is already asked for.
    mutating func requestNextPage() {
        guard let nextCursor, request.cursor != nextCursor else { return }
        request.cursor = nextCursor
    }

    /// Asks again for the page `request` asks for: the request changes, so the
    /// fetch runs again, on the same page.
    mutating func retry() {
        request.retries += 1
    }
}
