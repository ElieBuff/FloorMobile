//
//  BrandClientsList.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "All Brand": any client of the brand matching the search, straight from
/// the server (`ClientService.searchClients`, `.brand`), closest first, a page at a time
/// (`PagedSearchList`).
///
/// Below `Endpoint.clientSearchMinimumLength` characters, spaces around them
/// aside, it asks for more: the server refuses fewer. A first page that fails
/// gives way to its error, with "Try again"; a next one raises an alert whose
/// "Try again" fetches that page again, the pages above it kept. The device
/// has nothing to fall back on: it keeps the store's clients, not the brand's.
struct BrandClientsList: View {
    let query: String

    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services

    /// The first page the server failed, while its text is still the search:
    /// its error stands in for the list.
    @State private var failedSearch: PagedSearchFailure?
    @State private var alert: FloorAlert?

    /// The search as the server gets it, spaces around it aside.
    private var text: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        content
            // A new text, a new search: an error or an alert about the last
            // one goes.
            .onChange(of: text) {
                failedSearch = nil
                alert = nil
            }
            .floorAlert($alert)
    }

    /// The prompt until the search is long enough for the server; then its
    /// results, or the error of a first page it failed.
    @ViewBuilder
    private var content: some View {
        if text.count < Endpoint.clientSearchMinimumLength {
            ContentUnavailableView(
                String(localized: "Search the whole brand"),
                systemImage: "magnifyingglass",
                // The "3" mirrors `Endpoint.clientSearchMinimumLength`.
                description: Text("Type at least 3 characters of a name, an email or a phone number.")
            )
        } else if let failedSearch, failedSearch.query == text {
            failedFirstPage(failedSearch)
        } else {
            PagedSearchList(query: text) {
                try await services.clients.searchClients($0, in: .brand, after: $1, using: session.api)
            } onFailure: { failure in
                if failure.isFirstPage {
                    // Nothing of the server's on screen: the error takes the list's place.
                    failedSearch = failure
                } else {
                    // The pages already there stay; the alert fetches the one that failed.
                    alert = failure.alert
                }
            } row: { client in
                NavigationLink(value: ClientsRoute.profile(id: client.id)) {
                    ClientRow(client: client, display: .brand)
                }
            }
        }
    }

    /// What went wrong with a first page, and "Try again", which builds the
    /// list afresh — so it asks for that first page again.
    private func failedFirstPage(_ failure: PagedSearchFailure) -> some View {
        LoadFailureView(title: String(localized: "Search failed"), error: failure.error) {
            failedSearch = nil
        }
    }
}

// MARK: - Previews

#Preview("Before 3 characters") {
    BrandClientsList(query: "al")
        .ambientBackground()
        .environment(AppSession(auth: .preview, api: .preview))
        .environment(AppServices(container: try! ModelContainer(
            for: Client.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )))
}
