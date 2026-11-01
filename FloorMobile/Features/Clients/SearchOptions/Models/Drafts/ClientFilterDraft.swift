//
//  ClientFilterDraft.swift
//  FloorMobile
//

import Foundation

/// What the associate composes in "Filter" (`ClientFilterPickerView`): the
/// filters picked — the tenant's values ticked and a sentence's pills —, the
/// sentence, and where its filters stand: the one on its way to
/// `client/text-filters`, the one the pills came from, and what the last
/// answer said beside them.
///
/// Made from the list's filters (`ClientSearchOptions.filters`) when the
/// sheet opens; "Apply" writes `filters` back, and the rest goes with the
/// sheet. Not in `ClientSearchOptions`: that is what a search asks the
/// server, and the list starts its search over whenever it changes.
nonisolated struct ClientFilterDraft: Equatable, Sendable {
    /// The filters picked, one list as `client/search` takes it: the tenant's
    /// values ticked (`.value`) and a sentence's pills (`.filter`).
    var filters: [ClientFilterChoice] = []
    /// The sentence: the clients wanted, in the associate's words, what the
    /// arrow sends.
    var text = ""
    /// The text sent, trimmed, waiting for the server's answer; `nil` the
    /// rest of the time.
    var pendingText: String?
    /// The sentence the pills came from, while they are all there: the arrow
    /// does not send it again. `nil` once "Clear" or an X takes pills off, for
    /// the same words to bring them back.
    var lastFetched: String?
    /// What the last sentence sent left uncovered, said under its pills.
    var notUnderstood: [String] = []
    /// Why the last request failed, said under the card until the next one.
    var failure: String?

    /// Whether there is anything for "Clear" to take away: filters, or what
    /// the last answer said under the card.
    var canClear: Bool {
        !filters.isEmpty || !notUnderstood.isEmpty || failure != nil
    }

    /// Takes off every filter, ticked or pill, with what the last answer said
    /// and the sentence the pills came from. The field stays, and a sentence
    /// on its way goes on.
    mutating func clear() {
        filters = []
        lastFetched = nil
        notUnderstood = []
        failure = nil
    }

    // MARK: - Values

    /// Whether `value` is among the filter values picked.
    func isPicked(_ value: ClientFilterValue) -> Bool {
        filters.contains { $0.ref == value.ref }
    }

    /// The day picked for `value` — "Since a date" —, or `nil` while it is
    /// not picked or asks for no day.
    func day(pickedFor value: ClientFilterValue) -> Date? {
        guard let parameter = value.dateParameter,
              case .value(_, let parameters)? = filters.first(where: { $0.ref == value.ref }),
              let text = parameters[parameter.name]
        else { return nil }
        return Date(calendarDay: text)
    }

    /// Picks `value` of `filter`, with what the associate filled in for its
    /// parameters (`[name: text]`: the day of "Since a date"). A filter that
    /// takes one value (`single`) lets go of the one it had — the design's
    /// rule: picking "Since a date" deselects "Last 3 months". A value already
    /// picked takes the new parameters, never a second entry.
    mutating func pick(_ value: ClientFilterValue, of filter: ClientFilter, parameters: [String: String] = [:]) {
        if filter.selection == .single {
            let siblings = Set(filter.values.map(\.ref))
            filters.removeAll { $0.ref.map(siblings.contains) == true }
        } else {
            filters.removeAll { $0.ref == value.ref }
        }
        filters.append(.value(ref: value.ref, parameters: parameters))
    }

    /// Picks the value `ref` with `day`, the day the calendar confirmed for
    /// it — "Since a date" —, its filter found among the tenant's, `offered`,
    /// at that moment. Nothing changes for a ref no longer offered — the
    /// filters reloaded while the calendar was open — or for a value that
    /// asks for no day.
    mutating func pick(_ day: Date, forValue ref: String, in offered: [ClientFilter]) {
        guard let filter = ClientFilter.offering(ref, in: offered),
              let value = filter.values.first(where: { $0.ref == ref }),
              let parameter = value.dateParameter
        else { return }
        pick(value, of: filter, parameters: [parameter.name: day.calendarDay()])
    }

    /// Lets go of `value`.
    mutating func unpick(_ value: ClientFilterValue) {
        filters.removeAll { $0.ref == value.ref }
    }

    // MARK: - Pills

    /// The pills of the sentence, in their order: the filters it described,
    /// beside the values picked.
    var filterItems: [ClientFilterItem] {
        filters.compactMap(\.item)
    }

    /// Lets go of the pill `item`, by its `id` — two pills may read alike —,
    /// and lets the same sentence be sent again, to bring it back.
    mutating func remove(_ item: ClientFilterItem) {
        filters.removeAll { $0.item?.id == item.id }
        lastFetched = nil
    }

    // MARK: - Sentence

    /// Whether a text is waiting for the server's answer: the arrow and
    /// "Apply" wait.
    var hasPendingText: Bool {
        pendingText != nil
    }

    /// Whether the arrow sends the text: words — spaces and line breaks alone
    /// are none —, other than those the pills came from, and no other text
    /// waiting for its answer.
    var canSend: Bool {
        let words = trimmedText
        return !hasPendingText && !words.isEmpty && words != lastFetched
    }

    /// Sends the text, trimmed, the last failure dropped.
    mutating func send() {
        failure = nil
        pendingText = trimmedText
    }

    /// Takes the answer for the sentence sent: its filters in place of the
    /// last sentence's pills, the values picked left as they are, and what
    /// no filter covers. The arrow then stays away until the sentence
    /// changes.
    mutating func receive(_ answer: ClientFilterItems) {
        filters.removeAll { $0.item != nil }
        filters.append(contentsOf: answer.items.map(ClientFilterChoice.filter))
        notUnderstood = answer.notUnderstood
        lastFetched = pendingText
        pendingText = nil
    }

    /// Ends the request for the sentence sent on `failure`, said under the
    /// card: the pills stay as they were, and the sentence can be sent again.
    mutating func fail(_ failure: String) {
        self.failure = failure
        pendingText = nil
    }

    /// The text as the arrow sends it: trimmed.
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
