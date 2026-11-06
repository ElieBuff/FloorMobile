//
//  ClientFilterEditorTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

/// The requests around "Filter"'s draft: its total, and the filters of a
/// sentence. The network belongs to `ClientService`; what is under test here
/// is what the sheet shows before, after, and when it fails.
@Suite("Client filter editor")
@MainActor
struct ClientFilterEditorTests {

    // MARK: - Count

    @Test("The total is calculating until the count comes back, then shows it")
    func countShowsTheTotal() async throws {
        let world = try World { _ in (200, Data(#"{"total":664}"#.utf8)) }
        let editor = ClientFilterEditor(filters: [.value(ref: "a")], debounce: .zero)
        #expect(editor.total.isLoading)

        await editor.count(in: .mine, session: world.session, services: world.services)

        #expect(editor.total.value == 664)
    }

    @Test("A count that fails takes the last total away")
    func failedCountTakesTheTotalAway() async throws {
        let counted = try World { _ in (200, Data(#"{"total":664}"#.utf8)) }
        let pastTheLimit = try World { _ in (503, Data(#"{"error":"search_timeout"}"#.utf8)) }
        let editor = ClientFilterEditor(filters: [.value(ref: "a")], debounce: .zero)
        await editor.count(in: .mine, session: counted.session, services: counted.services)

        await editor.count(in: .mine, session: pastTheLimit.session, services: pastTheLimit.services)

        #expect(editor.total.error != nil)
        #expect(editor.total.value == nil)
    }

    // MARK: - Sentence

    @Test("A sentence's filters come back as pills, and the arrow stays away until it changes")
    func fetchGivesThePills() async throws {
        let world = try World { _ in (200, try Fixture.data("client_text_filters")) }
        let editor = ClientFilterEditor(filters: [])
        editor.draft.text = "VIP clients"
        editor.draft.send()

        await editor.fetchFilterItems(session: world.session, services: world.services)

        #expect(editor.draft.filterItems.map(\.label) == [
            "Clients VIP", "Plus de 10 000 € dépensés en 2026", "Sans opt-in email",
        ])
        #expect(!editor.draft.hasPendingText)
        #expect(!editor.draft.canSend)
    }

    @Test("Without a connection, a sentence's request says so")
    func networkFailureSaysConnection() async throws {
        let world = try World { _ in throw URLError(.notConnectedToInternet) }
        let editor = ClientFilterEditor(filters: [])
        editor.draft.text = "VIP clients"
        editor.draft.send()

        await editor.fetchFilterItems(session: world.session, services: world.services)

        #expect(editor.draft.failure == String(localized: "Reading a sentence needs a connection"))
        #expect(!editor.draft.hasPendingText)
        #expect(editor.draft.canSend)
    }

    @Test("Any other failure of a sentence's request asks to try again")
    func serverFailureAsksToTryAgain() async throws {
        let world = try World { _ in (502, Data(#"{"error":"Failed to read the sentence"}"#.utf8)) }
        let editor = ClientFilterEditor(filters: [])
        editor.draft.text = "VIP clients"
        editor.draft.send()

        await editor.fetchFilterItems(session: world.session, services: world.services)

        #expect(editor.draft.failure == String(localized: "Couldn't read the sentence. Try again."))
        #expect(!editor.draft.hasPendingText)
    }

    @Test("With no sentence sent, nothing is asked")
    func noPendingTextNoRequest() async throws {
        let world = try World { _ in
            Issue.record("No request expected")
            return (200, Data())
        }
        let editor = ClientFilterEditor(filters: [])

        await editor.fetchFilterItems(session: world.session, services: world.services)

        #expect(editor.draft == ClientFilterDraft())
    }

    // MARK: - Helpers

    /// A session whose every request gets `answer`'s status and body.
    @MainActor
    private struct World {
        let session: AppSession
        let services: AppServices

        init(answer: @escaping @Sendable (URLRequest) throws -> (Int, Data)) throws {
            let container = try ModelContainer(
                for: Client.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let client = APIClient(
                baseURL: URL(string: "https://api.example.com")!,
                tokens: TokenProviding(validToken: { "t" }, refreshedToken: { "t" }),
                session: MockURLProtocol.session { request in
                    let (statusCode, body) = try answer(request)
                    let response = HTTPURLResponse(
                        url: request.url ?? URL(string: "https://invalid")!,
                        statusCode: statusCode, httpVersion: nil, headerFields: nil
                    )!
                    return (response, body)
                }
            )
            // The associate in memory: never the simulator's `UserDefaults`.
            session = AppSession(auth: .preview, api: client, salesAssociateStorage: .inMemory(), storeStorage: .inMemory())
            services = AppServices(container: container)
        }
    }
}
