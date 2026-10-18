//
//  SearchPagesTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

@Suite("Search pages")
struct SearchPagesTests {

    /// A made-up result: an id is all the pages look at.
    nonisolated private struct Match: Identifiable {
        let id: Int
    }

    private static func matches(_ ids: ClosedRange<Int>) -> [Match] {
        ids.map { Match(id: $0) }
    }

    @Test("A new search asks for its first page")
    func asksForTheFirstPage() {
        let pages = SearchPages<Match>()

        #expect(pages.request.isFirstPage)
        #expect(pages.needsFetch(pages.request))
        #expect(pages.loaded == nil)
    }

    @Test("The next page is asked for once, from where it starts, and is not a first page")
    func nextPageAskedForOnce() {
        var pages = SearchPages<Match>()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)

        pages.requestNextPage()
        // Another row near the end appears: the page is already asked for.
        pages.requestNextPage()

        #expect(pages.request == SearchPages<Match>.Request(cursor: "page-2"))
        #expect(!pages.request.isFirstPage)
        #expect(pages.needsFetch(pages.request))
    }

    @Test("Nothing is asked for after the last page")
    func nothingAfterTheLastPage() {
        var pages = SearchPages<Match>()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        // Page 2 is the last: no cursor after it.
        pages.land(Self.matches(4...6), next: nil, for: pages.request)
        let last = pages.request

        pages.requestNextPage()

        #expect(pages.request == last)
        #expect(!pages.needsFetch(pages.request))
    }

    @Test("A page lands once, though asked for again after it landed")
    func pageLandsOnce() {
        var pages = SearchPages<Match>()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        pages.land(Self.matches(4...6), next: "page-3", for: pages.request)

        // Back on screen, the list asks again for the page it shows…
        #expect(!pages.needsFetch(pages.request))
        // …and a "Try again" left on screen comes after that page landed.
        pages.retry()
        #expect(!pages.needsFetch(pages.request))
        #expect(pages.items.map(\.id) == [1, 2, 3, 4, 5, 6])
    }

    @Test("A retry asks again for exactly the page that failed")
    func retryAsksForTheFailedPage() {
        var pages = SearchPages<Match>()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()
        // Page 2 fails: nothing lands.
        let failed = pages.request

        pages.retry()

        // A new request, so the task runs again — on the same page.
        #expect(pages.request != failed)
        #expect(pages.request.cursor == failed.cursor)
        #expect(pages.needsFetch(pages.request))
        #expect(pages.items.map(\.id) == [1, 2, 3])
    }

    @Test("A client the server repeats on the next page is shown once")
    func repeatedClientShownOnce() {
        var pages = SearchPages<Match>()
        pages.land(Self.matches(1...3), next: "page-2", for: pages.request)
        pages.requestNextPage()

        // A refresh of the server's dictionary between the two pages: client 3 comes again.
        pages.land(Self.matches(3...5), next: nil, for: pages.request)

        #expect(pages.items.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test("A first page that comes back empty is told from one not back yet")
    func emptyFirstPageLands() {
        var pages = SearchPages<Match>()
        let first = pages.request

        pages.land([], next: nil, for: first)

        #expect(pages.items.isEmpty)
        #expect(pages.loaded == first)
    }
}
