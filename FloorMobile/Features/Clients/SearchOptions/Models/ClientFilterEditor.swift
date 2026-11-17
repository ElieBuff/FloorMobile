//
//  ClientFilterEditor.swift
//  FloorMobile
//

import Foundation

/// "Sort & filter"'s draft (`ClientFilterDraft`) and the two requests around
/// it: the draft's total (`client/count`), and the filters of the sentence
/// sent (`client/text-filters`).
///
/// Held as `@State` by the sheet (`ClientSortFilterSheet`), whose "Show"
/// button says the total. The network is `ClientService`'s; what lives here
/// is the choreography around it — the pause before a count, what shows
/// meanwhile, an answer dropped once its request is cancelled, what a
/// failure says. The draft stays a value type, its rules tested on their own.
///
/// Not the sheet's own `@State`: there, the count and its choreography would
/// sit in the view, untested. Not a `Service` either: a service is built once
/// and shared by the whole app, while this state belongs to one open sheet.
///
/// The sheet's `.task(id:)` runs the count: a newer change, or the sheet
/// closing, cancels the one running, and what comes back for it is dropped
/// here, as `PagedSearchList` does. Reading a sentence has no caller since
/// 16/11 — the sentence is only drawn (the user's decision) —, until the
/// voice screens call it again.
@Observable
final class ClientFilterEditor {
    /// The sort and the filters being picked, and the sentence.
    var draft: ClientFilterDraft
    /// The draft's total: on its way from a change to its answer — and from
    /// the start, for the first count —, then counted, or failed.
    private(set) var total: Loadable<Int> = .loading

    /// How long the changes must pause before the total is asked for: the
    /// search's own pause (`PagedSearchList`). Injectable so a test need not
    /// wait it out.
    let debounce: Duration

    init(options: ClientSearchOptions, debounce: Duration = .milliseconds(300)) {
        draft = ClientFilterDraft(options: options)
        self.debounce = debounce
    }

    /// Counts the draft's clients once the changes pause, "Show" alone from
    /// the change on. One `client/count` for the last state, as the route
    /// asks — a request given up on runs on, server side. It counts what the
    /// filters keep among the associate's own clients, whatever text the list
    /// has: how far the filters reach. The sort changes no total.
    ///
    /// A newer change cancels the wait — that total is never asked for —, and
    /// the newer count keeps "Show" alone. Any failure — no connection, past
    /// the server's limit, refused — takes the total away. A 409
    /// `filters_changed`, the tenant's filters changed since the app's launch,
    /// is deliberately not handled: too rare to be worth the code.
    func count(session: AppSession, services: AppServices) async {
        total = .loading
        do {
            try await Task.sleep(for: debounce)
            let count = try await services.clients.countClients(nil, filters: draft.options.filters, using: session.api)
            guard !Task.isCancelled else { return }
            total = .loaded(count)
        } catch {
            guard !Task.isCancelled else { return }
            total = .failed(error)
        }
    }

    /// Fetches the filters of the sentence sent, for up to 80 s, for the
    /// draft to take in place of the last sentence's pills
    /// (`ClientFilterDraft.receive`), or the failure (`ClientFilterDraft.fail`).
    /// Either way, the sentence can be sent again. No caller since 16/11: the
    /// sentence is only drawn, until the voice screens.
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
    /// same, as in `ClientsView.failedFirstPage`: no look into
    /// `AppError.network`'s underlying error.
    private static func failure(for error: Error) -> String {
        if case .network? = error as? AppError {
            String(localized: "Reading a sentence needs a connection")
        } else {
            String(localized: "Couldn't read the sentence. Try again.")
        }
    }
}
