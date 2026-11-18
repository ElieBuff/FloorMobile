//
//  ClientFilterEditorTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

/// The requests around an editor's draft: its total, which "Sort & filter"
/// shows, and the filters of its sentence, which "Your description" reads on
/// a draft made of the sentence alone, then hands to "Sort & filter"'s. The
/// network belongs to `ClientService`; what is under test here is what a
/// screen shows before, after, and when it fails.
@Suite("Client filter editor")
@MainActor
struct ClientFilterEditorTests {

    // MARK: - Draft

    @Test("An editor made from a draft keeps its sentence and its filters")
    func editorKeepsItsDraft() {
        let draft = ClientFilterDraft(
            options: ClientSearchOptions(filters: [.value(ref: "a")]),
            text: "VIP clients"
        )

        let editor = ClientFilterEditor(draft: draft)

        #expect(editor.draft == draft)
    }

    // MARK: - Count

    @Test("A count is on its way from the start, then the total shows")
    func countShowsTheTotal() async throws {
        let world = try World { _ in (200, Data(#"{"total":664}"#.utf8)) }
        let editor = ClientFilterEditor(options: ClientSearchOptions(filters: [.value(ref: "a")]), debounce: .zero)
        #expect(editor.isCounting)
        #expect(editor.total == nil)

        await editor.count(session: world.session, services: world.services)

        #expect(editor.total == 664)
        #expect(!editor.isCounting)
    }

    @Test("A newer count keeps the last total while it runs")
    func newerCountKeepsTheLastTotal() async throws {
        let world = try World { _ in (200, Data(#"{"total":664}"#.utf8)) }
        let editor = ClientFilterEditor(options: ClientSearchOptions(filters: [.value(ref: "a")]), debounce: .zero)
        await editor.count(session: world.session, services: world.services)

        // A count cancelled as it starts stops before it writes an answer:
        // what it leaves is what shows while a newer count runs.
        let newer = Task { await editor.count(session: world.session, services: world.services) }
        newer.cancel()
        await newer.value

        #expect(editor.isCounting)
        #expect(editor.total == 664)
    }

    @Test("A count that fails takes the last total away")
    func failedCountTakesTheTotalAway() async throws {
        let counted = try World { _ in (200, Data(#"{"total":664}"#.utf8)) }
        let pastTheLimit = try World { _ in (503, Data(#"{"error":"search_timeout"}"#.utf8)) }
        let editor = ClientFilterEditor(options: ClientSearchOptions(filters: [.value(ref: "a")]), debounce: .zero)
        await editor.count(session: counted.session, services: counted.services)

        await editor.count(session: pastTheLimit.session, services: pastTheLimit.services)

        #expect(editor.total == nil)
        #expect(!editor.isCounting)
    }

    // MARK: - Sentence

    @Test("Reading a sentence sends it, its filters come back as pills, and it is not sent again until it changes")
    func readingGivesThePills() async throws {
        let world = try World { _ in (200, try Fixture.data("client_text_filters")) }
        let editor = ClientFilterEditor(draft: ClientFilterDraft(text: "VIP clients"))

        await editor.readSentence(session: world.session, services: world.services)

        #expect(editor.draft.filterItems.map(\.label) == [
            "Clients VIP", "Plus de 10 000 € dépensés en 2026", "Sans opt-in email",
        ])
        #expect(!editor.draft.hasPendingText)
        #expect(!editor.draft.canSend)
    }

    @Test("Filters read on a draft of the sentence alone go after another draft's pills; read again, they add nothing")
    func filtersReadAreApplied() async throws {
        let world = try World { _ in (200, try Fixture.data("client_text_filters")) }
        let earlier = ClientFilterItem(label: "Habite Paris", condition: .object(["field": .string("client.city")]))
        var sortAndFilter = ClientFilterDraft(
            options: ClientSearchOptions(filters: [.filter(earlier)]),
            text: "VIP clients"
        )
        let first = ClientFilterEditor(draft: ClientFilterDraft(text: sortAndFilter.text))
        await first.readSentence(session: world.session, services: world.services)

        sortAndFilter.apply(first.draft.filterItems)

        #expect(sortAndFilter.filterItems.map(\.label) == [
            "Habite Paris", "Clients VIP", "Plus de 10 000 € dépensés en 2026", "Sans opt-in email",
        ])
        #expect(sortAndFilter.text.isEmpty)

        // The same sentence typed and read once more: new ids, the same
        // conditions.
        sortAndFilter.text = "VIP clients"
        let second = ClientFilterEditor(draft: ClientFilterDraft(text: sortAndFilter.text))
        await second.readSentence(session: world.session, services: world.services)

        sortAndFilter.apply(second.draft.filterItems)

        #expect(sortAndFilter.filterItems.count == 4)
        #expect(sortAndFilter.text.isEmpty)
    }

    @Test("Without a connection, a sentence's request says so")
    func networkFailureSaysConnection() async throws {
        let world = try World { _ in throw URLError(.notConnectedToInternet) }
        let editor = ClientFilterEditor(draft: ClientFilterDraft(text: "VIP clients"))

        await editor.readSentence(session: world.session, services: world.services)

        #expect(editor.draft.failure == String(localized: "Reading a sentence needs a connection"))
        #expect(!editor.draft.hasPendingText)
        #expect(editor.draft.canSend)
    }

    @Test("Any other failure of a sentence's request asks to try again")
    func serverFailureAsksToTryAgain() async throws {
        let world = try World { _ in (502, Data(#"{"error":"Failed to read the sentence"}"#.utf8)) }
        let editor = ClientFilterEditor(draft: ClientFilterDraft(text: "VIP clients"))

        await editor.readSentence(session: world.session, services: world.services)

        #expect(editor.draft.failure == String(localized: "Couldn't read the sentence. Try again."))
        #expect(!editor.draft.hasPendingText)
    }

    @Test("After a failure, reading again sends the sentence once more and drops the message")
    func readingAgainAfterAFailure() async throws {
        let offline = try World { _ in throw URLError(.notConnectedToInternet) }
        let online = try World { _ in (200, try Fixture.data("client_text_filters")) }
        let editor = ClientFilterEditor(draft: ClientFilterDraft(text: "VIP clients"))
        await editor.readSentence(session: offline.session, services: offline.services)
        #expect(editor.draft.failure != nil)

        await editor.readSentence(session: online.session, services: online.services)

        #expect(editor.draft.failure == nil)
        #expect(editor.draft.filterItems.count == 3)
        #expect(!editor.draft.hasPendingText)
    }

    @Test("A sentence of spaces and line breaks alone asks nothing")
    func blankSentenceNoRequest() async throws {
        let world = try World { _ in
            Issue.record("No request expected")
            return (200, Data())
        }
        let draft = ClientFilterDraft(text: "  \n ")
        let editor = ClientFilterEditor(draft: draft)

        await editor.readSentence(session: world.session, services: world.services)

        #expect(editor.draft == draft)
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
