//
//  SearchPages.swift
//  FloorMobile
//

/// The pages of a server search, as `PagedSearchList` shows them: which
/// search they belong to, what is on screen, which page to ask for next, and
/// what a failed page asks for again.
///
/// A value type rather than `@State` scattered in the view, for the reason
/// `CalendarExpansion` is one: the rules are delicate, and none of them can be
/// checked by scrolling a list by hand — `SearchPagesTests` checks them
/// instead:
/// - a new search starts from nothing (`start`), and the same search again
///   changes nothing;
/// - a page lands once, whichever try fetched it — and never one of a search
///   or a page no longer asked for, which came back late;
/// - the next page is asked for once, and never after the last;
/// - a retry asks again for exactly the page that failed, and does nothing for
///   a search or a page left behind;
/// - a client the server repeats on the next page is shown once;
/// - the list is loading while the page asked for is neither on screen nor
///   failed.
nonisolated struct SearchPages<Item: Identifiable> {
    /// What is on screen, in the server's order.
    private(set) var items: [Item] = []
    /// The page to fetch next, or again.
    private(set) var request: Request
    /// The request whose page landed last — `nil` until the first does: what
    /// tells a first page that came back empty from one still on its way, or
    /// failed.
    private(set) var loaded: Request?
    /// The request whose page failed, while it is the one asked for: the list
    /// stops loading until a retry.
    private(set) var failed: Request?
    /// Where the next page starts — `nil` before the first lands, and once
    /// there is none.
    private var nextCursor: String?

    /// The pages of `search`, nothing on screen yet: its first page is asked
    /// for.
    init(search: AnyHashable) {
        request = Request(search: search)
    }

    /// What a page is asked for with: the search it belongs to, where it
    /// starts, and how many tries.
    struct Request: Equatable {
        /// The search the page belongs to — its query and whatever else it
        /// depends on: what tells a late answer from the one asked for.
        var search: AnyHashable
        /// The page to fetch: `nil` for the first.
        var cursor: String?
        /// Bumped by `retry(_:)`: the request changes without changing what it
        /// asks for.
        var retries = 0

        /// Whether nothing of the search is on screen before this page.
        var isFirstPage: Bool { cursor == nil }

        /// Whether `other` asks for the same page of the same search, whatever
        /// the tries.
        func asksForSamePage(as other: Request) -> Bool {
            search == other.search && cursor == other.cursor
        }
    }

    /// Whether the page asked for is on its way: neither on screen nor
    /// failed.
    var isLoading: Bool {
        let landed = loaded.map { $0.asksForSamePage(as: request) } ?? false
        return !landed && failed != request
    }

    /// Starts `search` over from nothing — no page, cursor or failure of the
    /// last one — and asks for its first page. Nothing for the search already
    /// on screen.
    mutating func start(_ search: AnyHashable) {
        guard search != request.search else { return }
        items = []
        loaded = nil
        failed = nil
        nextCursor = nil
        request = Request(search: search)
    }

    /// Whether `request`'s page is still to fetch — not once it is on screen,
    /// whichever try fetched it: back on screen, the list asks again for the
    /// page it shows, and a "Try again" left on screen can come after that
    /// page landed. The search counts as much as the cursor: a page of
    /// another search is to fetch though the same page of this one landed.
    func needsFetch(_ request: Request) -> Bool {
        guard let loaded else { return true }
        return !loaded.asksForSamePage(as: request)
    }

    /// Notes that `request`'s page is on its way again, while it is the one
    /// asked for: a page that failed, fetched again as the list comes back on
    /// screen, shows its spinner rather than nothing.
    mutating func fetching(_ request: Request) {
        guard request == self.request else { return }
        failed = nil
    }

    /// Puts `page`, fetched for `request`, under what is on screen, and keeps
    /// where the next page starts — unless `request` no longer asks for the
    /// page asked for: a late answer to a search or a page left behind is
    /// dropped. A client already on screen is left out: between two pages, a
    /// refresh of the server's name dictionary can repeat a few
    /// (`client-fuzzy-match.service.ts`).
    mutating func land(_ page: [Item], next: String?, for request: Request) {
        guard request.asksForSamePage(as: self.request) else { return }
        let shown = Set(items.map(\.id))
        items += page.filter { !shown.contains($0.id) }
        nextCursor = next
        loaded = request
        failed = nil
    }

    /// Notes that `request`'s page failed, while it is the one asked for: a
    /// late failure of a request left behind changes nothing.
    mutating func fail(_ request: Request) {
        guard request == self.request else { return }
        failed = request
    }

    /// Asks for the page after the last one — once: nothing if there is none
    /// left, or if it is already asked for.
    mutating func requestNextPage() {
        guard let nextCursor, request.cursor != nextCursor else { return }
        request.cursor = nextCursor
    }

    /// Asks again for the page `request` asked for, while it is still the one
    /// asked for: the request changes, so the fetch runs again, on the same
    /// page. Nothing for a search or a page left behind — a "Try again" from
    /// before the search changed.
    mutating func retry(_ request: Request) {
        guard request == self.request else { return }
        failed = nil
        self.request.retries += 1
    }
}
