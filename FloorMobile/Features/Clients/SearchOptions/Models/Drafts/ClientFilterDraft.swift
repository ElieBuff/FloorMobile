//
//  ClientFilterDraft.swift
//  FloorMobile
//

import Foundation

/// What the associate composes in "Sort & filter" (`ClientSortFilterSheet`):
/// the sort and the filters picked — the tenant's values ticked and a
/// sentence's pills —, the sentence, and where its filters stand: the one on
/// its way to `client/text-filters`, the one the pills came from, and what the
/// last answer said beside them.
///
/// Made from the list's options (`ClientSearchOptions`) when the sheet opens;
/// "Show" writes `options` back, and the rest goes with the sheet. The
/// sentence's state beside them rather than in `ClientSearchOptions`: that is
/// what a search asks the server, and the list starts its search over
/// whenever it changes.
///
/// The sentence is only drawn since 16/11 (the user's decision): typed or
/// dictated, never sent. Its rules below — sending it, its answer, its pills
/// — have no caller until the sentence's arrow sends it
/// (`ClientSortFilterSheet`).
nonisolated struct ClientFilterDraft: Equatable, Sendable {
    /// The longest sentence `client/text-filters` takes, in characters
    /// (`clientTextFiltersRequestSchema`, 500 once trimmed): the field stops
    /// there, and so does its dictation (`ClientVoiceSearchSheet`).
    static let maximumTextLength = 500

    /// The sort and the filters picked, as `client/search` takes them: the
    /// sort through `ClientSearchOptions.pick`, the filters in one list — the
    /// tenant's values ticked (`.value`) and a sentence's pills (`.filter`).
    var options = ClientSearchOptions()
    /// The sentence: the clients wanted, in the associate's words — typed or
    /// dictated, cut at `maximumTextLength`.
    var text = "" {
        didSet {
            if text.count > Self.maximumTextLength {
                text = String(text.prefix(Self.maximumTextLength))
            }
        }
    }
    /// The text sent, trimmed, waiting for the server's answer; `nil` the
    /// rest of the time.
    var pendingText: String?
    /// The sentence the pills came from, while they are all there: it is not
    /// sent again. `nil` once "Clear" or an X takes pills off, for the same
    /// words to bring them back.
    var lastFetched: String?
    /// What the last sentence sent left uncovered.
    var notUnderstood: [String] = []
    /// Why the last request for a sentence's filters failed, until the next
    /// one.
    var failure: String?

    /// Whether there is anything for "Clear" to take away: a sort picked,
    /// filters, or what the last answer said.
    var canClear: Bool {
        options != ClientSearchOptions() || !notUnderstood.isEmpty || failure != nil
    }

    /// Puts the server's default sort back and takes off every filter, ticked
    /// or pill, with what the last answer said and the sentence the pills came
    /// from. The field stays, and a sentence on its way goes on.
    mutating func clear() {
        options = ClientSearchOptions()
        lastFetched = nil
        notUnderstood = []
        failure = nil
    }

    // MARK: - Values

    /// Whether `value` is among the filter values picked.
    func isPicked(_ value: ClientFilterValue) -> Bool {
        options.filters.contains { $0.ref == value.ref }
    }

    /// The day picked for `value` — "Since a date" —, or `nil` while it is
    /// not picked or asks for no day.
    func day(pickedFor value: ClientFilterValue) -> Date? {
        guard let parameter = value.dateParameter,
              case .value(_, let parameters)? = options.filters.first(where: { $0.ref == value.ref }),
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
            options.filters.removeAll { $0.ref.map(siblings.contains) == true }
        } else {
            options.filters.removeAll { $0.ref == value.ref }
        }
        options.filters.append(.value(ref: value.ref, parameters: parameters))
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
        options.filters.removeAll { $0.ref == value.ref }
    }

    // MARK: - Pills

    /// The pills of the sentence, in their order: the filters it described,
    /// beside the values picked.
    var filterItems: [ClientFilterItem] {
        options.filters.compactMap(\.item)
    }

    /// Lets go of the pill `item`, by its `id` — two pills may read alike —,
    /// and lets the same sentence be sent again, to bring it back.
    mutating func remove(_ item: ClientFilterItem) {
        options.filters.removeAll { $0.item?.id == item.id }
        lastFetched = nil
    }

    // MARK: - Sentence

    /// Whether a text is waiting for the server's answer.
    var hasPendingText: Bool {
        pendingText != nil
    }

    /// Whether the text can be sent: words — spaces and line breaks alone are
    /// none —, other than those the pills came from, and no other text waiting
    /// for its answer.
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
    /// no filter covers. The same words are then not sent again until the
    /// sentence changes.
    mutating func receive(_ answer: ClientFilterItems) {
        options.filters.removeAll { $0.item != nil }
        options.filters.append(contentsOf: answer.items.map(ClientFilterChoice.filter))
        notUnderstood = answer.notUnderstood
        lastFetched = pendingText
        pendingText = nil
    }

    /// Ends the request for the sentence sent on `failure`: the pills stay as
    /// they were, and the sentence can be sent again.
    mutating func fail(_ failure: String) {
        self.failure = failure
        pendingText = nil
    }

    /// The text as it is sent: trimmed.
    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
