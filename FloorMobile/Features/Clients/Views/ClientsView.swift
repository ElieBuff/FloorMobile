//
//  ClientsView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// The Clients tab: one search field, and a choice of where to look — the
/// associate's own clients, searched on the server from
/// `Endpoint.clientSearchMinimumLength` characters and on the device below
/// that or when the server does not answer; or the whole brand, on the
/// server. The query is shared, so switching scope keeps what was typed.
struct ClientsView: View {
    @State private var query = ""
    @State private var scope = Scope.mine

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Clients"), selection: $scope) {
                ForEach(Scope.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch scope {
            case .mine:
                MyClientsList(query: query)
            case .brand:
                BrandClientsList(query: query)
            }
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Name, email or phone")
        )
        .ambientBackground()
        .appHeader()
    }

    /// Where the search looks.
    private enum Scope: CaseIterable {
        /// The associate's own clients, on the server or on the device — see
        /// `MyClientsList`.
        case mine
        /// Any client of the brand, on the server.
        case brand

        var title: String {
            switch self {
            case .mine: String(localized: "My Clients")
            case .brand: String(localized: "All Brand")
            }
        }
    }
}

// MARK: - Previews

#Preview {
    let container = try! ModelContainer(
        for: Client.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Client(
        id: "1", externalId: "1", firstName: "Alice", lastName: "Martinez",
        primaryEmail: "alice.martinez@example.com", primaryPhone: "+33 6 12 34 56 78"
    ))
    return NavigationStack {
        ClientsView()
    }
    .modelContainer(container)
    .environment(AppSession(auth: .preview, api: .preview))
    .environment(AppServices(container: container))
}
