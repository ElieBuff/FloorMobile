//
//  ClientFilterEditor.swift
//  FloorMobile
//

import Foundation

/// "Filter"'s draft (`ClientFilterDraft`) and the two requests around it:
/// the draft's total (`client/count`), and the filters of the sentence sent
/// (`client/text-filters`).
///
/// Held as `@State` by the sheet (`ClientFilterPickerView`), which hands it
/// to its bar (`ClientFilterBar`): both show it. The network is
/// `ClientService`'s; what lives here is the choreography around it — the
/// pause before a count, what shows meanwhile, what a failure says. The
/// draft stays a value type, its rules tested on their own.
///
/// Not the sheet's own `@State`: there, the calls and the choice of failure
/// message would sit in the view, untested, and the bar would take the
/// draft's binding and its total. Not a `Service` either: a service is built
/// once and shared by the whole app, while this state belongs to one open
/// sheet.
///
/// The sheet's `.task(id:)` runs each request: a newer tick or sentence, or
/// the sheet closing, cancels the one running, and what comes back for it is
/// dropped here, as `PagedSearchList` does.
@Observable
final class ClientFilterEditor {
    /// The picks being made, and the sentence.
    var draft: ClientFilterDraft
    /// The draft's total: on its way from a tick to its answer — and from the
    /// start, for the first count —, then counted, or failed.
    private(set) var total: Loadable<Int> = .loading

    /// How long the ticks must pause before the total is asked for: the
    /// search's own pause (`PagedSearchList`). Injectable so a test need not
    /// wait it out.
    let debounce: Duration

    init(filters: [ClientFilterChoice], debounce: Duration = .milliseconds(300)) {
        draft = ClientFilterDraft(filters: filters)
        self.debounce = debounce
    }

    /// Counts the draft's clients in `scope` once the ticks pause,
    /// "Calculating…" shown from the tick on. One `client/count` for the last
    /// state, as the route asks — a request given up on runs on, server side.
    /// It counts what the filters keep, whatever text the list has: how far
    /// the filters reach. They only travel with `.mine`
    /// (`Endpoint.countClients`), and only "My Clients" opens the sheet.
    ///
    /// A newer tick cancels the wait — that total is never asked for —, and
    /// the newer count keeps "Calculating…". Any failure — no connection, past
    /// the server's limit, refused — takes the total away. A 409
    /// `filters_changed`, the tenant's filters changed since the app's launch,
    /// is deliberately not handled: too rare to be worth the code.
    func count(in scope: ClientSearchScope, session: AppSession, services: AppServices) async {
        total = .loading
        do {
            try await Task.sleep(for: debounce)
            let count = try await services.clients.countClients(
                nil, in: scope, filters: draft.filters, using: session.api
            )
            guard !Task.isCancelled else { return }
            total = .loaded(count)
        } catch {
            guard !Task.isCancelled else { return }
            total = .failed(error)
        }
    }

    /// Fetches the filters of the sentence sent, for up to 80 s, for the
    /// draft to take in place of the last sentence's pills
    /// (`ClientFilterDraft.receive`); a failure is said under the card.
    /// Either way, the arrow and "Apply" come back.
    func fetchFilterItems(session: AppSession, services: AppServices) async {
        guard let text = draft.pendingText else { return }
        do {
            let answer = try await services.clients.filterItems(from: text, using: session.api)
            guard !Task.isCancelled else { return }
            draft.receive(answer)
        } catch {
            guard !Task.isCancelled else { return }
            draft.fail(Self.failure(for: error))
        }
    }

    /// What a failed request for a sentence's filters says. Any network error
    /// — no connection, or a server silent past the request's 90 s — says the
    /// same, as in `MyClientsList.failedFirstPage`: no look into
    /// `AppError.network`'s underlying error.
    private static func failure(for error: Error) -> String {
        if case .network? = error as? AppError {
            String(localized: "Reading a sentence needs a connection")
        } else {
            String(localized: "Couldn't read the sentence. Try again.")
        }
    }
}
