//
//  ClientsView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// The Clients tab: one search field, and a choice of where to look — the
/// associate's own clients, searched on the server from
/// `searchMinimumLength` characters or once a sort or a filter is picked, and
/// on the device otherwise, or when the server does not answer and no filter
/// is picked (`MyClientsList`); or the whole brand, on the server. The query
/// is shared, so switching scope keeps what was typed.
struct ClientsView: View {
    /// The fewest characters, spaces aside, a search sends to the server,
    /// which refuses fewer: the lists' decision under this tab — below it,
    /// "All Brand" asks for more, and "My Clients" searches the device, or,
    /// with a sort or a filter picked, asks the server without the text.
    static let searchMinimumLength = 3

    @State private var query = ""
    @State private var scope = ClientSearchScope.mine

    var body: some View {
        VStack(spacing: 0) {
            Picker(String(localized: "Clients"), selection: $scope) {
                ForEach(ClientSearchScope.allCases, id: \.self) { scope in
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
