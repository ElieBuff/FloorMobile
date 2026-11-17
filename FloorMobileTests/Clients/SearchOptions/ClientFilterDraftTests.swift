//
//  ClientFilterDraftTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Client filter draft")
struct ClientFilterDraftTests {

    // MARK: - Sentence

    @Test("A sentence typed past the server's 500 characters is cut there")
    func typedTextCut() {
        var draft = ClientFilterDraft()

        draft.text = String(repeating: "a", count: 520)

        #expect(draft.text.count == ClientFilterDraft.maximumTextLength)
    }

    @Test("A dictation added past 500 characters is cut there, the typed start kept")
    func dictationAddedCut() {
        var draft = ClientFilterDraft()
        draft.text = String(repeating: "a", count: 490)

        draft.text.append(dictation: "VIC clients on WhatsApp")

        #expect(draft.text.count == ClientFilterDraft.maximumTextLength)
        #expect(draft.text.hasPrefix(String(repeating: "a", count: 490)))
    }

    @Test("A sentence within 500 characters is kept whole")
    func shortTextKept() {
        var draft = ClientFilterDraft()

        draft.text = "VIC clients on WhatsApp"

        #expect(draft.text == "VIC clients on WhatsApp")
    }

    // MARK: - Values

    @Test("Ticking a value of a multiple filter keeps its other values ticked")
    func multipleKeepsOthers() {
        let tier = Self.tier
        var draft = ClientFilterDraft()

        draft.pick(tier.values[0], of: tier)
        draft.pick(tier.values[1], of: tier)

        #expect(draft.options.filters.map(\.ref) == ["tier-VIC", "tier-VIP"])
    }

    @Test("Ticking a value of a single filter lets go of the one it had, not of another filter's")
    func singleLetsGoOfItsOwnOnly() {
        let tier = Self.tier
        let created = Self.created
        var draft = ClientFilterDraft()
        draft.pick(tier.values[0], of: tier)
        draft.pick(created.values[0], of: created)

        draft.pick(created.values[1], of: created)

        #expect(draft.options.filters.map(\.ref) == ["tier-VIC", "created-last6Months"])
    }

    @Test("A filter whose selection this app does not know ticks like a multiple one, as the server reads it")
    func unknownSelectionTicksLikeMultiple() {
        let filter = ClientFilter(id: "f", titleKey: "k", selectionRaw: "SOMETIMES", rank: 0, values: [
            ClientFilterValue(ref: "a", labelKey: nil, label: "A", parameters: []),
            ClientFilterValue(ref: "b", labelKey: nil, label: "B", parameters: []),
        ])
        var draft = ClientFilterDraft()

        draft.pick(filter.values[0], of: filter)
        draft.pick(filter.values[1], of: filter)

        #expect(draft.options.filters.map(\.ref) == ["a", "b"])
    }

    @Test("Unticking lets go of that value only")
    func unpickLetsGoOfThatValue() {
        let tier = Self.tier
        var draft = ClientFilterDraft()
        draft.pick(tier.values[0], of: tier)
        draft.pick(tier.values[1], of: tier)

        draft.unpick(tier.values[0])

        #expect(!draft.isPicked(tier.values[0]))
        #expect(draft.isPicked(tier.values[1]))
        #expect(draft.options.filters.map(\.ref) == ["tier-VIP"])
    }

    @Test("Ticking a value again takes its new parameters, never a second entry")
    func pickAgainReplacesParameters() {
        let created = Self.created
        let since = created.values[2]
        var draft = ClientFilterDraft()

        draft.pick(since, of: created, parameters: ["since": "2026-07-01"])
        draft.pick(since, of: created, parameters: ["since": "2026-08-15"])

        #expect(draft.options.filters == [.value(ref: "created-since", parameters: ["since": "2026-08-15"])])
    }

    @Test("The day picked for a value is read back from its parameter; none for a value not picked or asking for none")
    func dayPickedForReadsTheParameter() throws {
        let created = Self.created
        let since = created.values[2]
        var draft = ClientFilterDraft()
        #expect(draft.day(pickedFor: since) == nil)

        draft.pick(since, of: created, parameters: ["since": "2026-07-01"])

        let day = try #require(draft.day(pickedFor: since))
        #expect(day.calendarDay() == "2026-07-01")
        #expect(draft.day(pickedFor: created.values[0]) == nil)
    }

    @Test("The day confirmed ticks its value, with the day as its parameter")
    func dayConfirmedTicksItsValue() throws {
        let created = Self.created
        let day = try #require(Date(calendarDay: "2026-07-01"))
        var draft = ClientFilterDraft()

        draft.pick(day, forValue: "created-since", in: [Self.tier, created])

        #expect(draft.options.filters == [.value(ref: "created-since", parameters: ["since": "2026-07-01"])])
        #expect(draft.day(pickedFor: created.values[2])?.calendarDay() == "2026-07-01")
    }

    @Test("A single filter's day lets go of the value it had, not of another filter's")
    func dayConfirmedLetsGoOfItsFilterValue() throws {
        let tier = Self.tier
        let created = Self.created
        let day = try #require(Date(calendarDay: "2026-07-01"))
        var draft = ClientFilterDraft()
        draft.pick(tier.values[0], of: tier)
        draft.pick(created.values[0], of: created)

        draft.pick(day, forValue: "created-since", in: [tier, created])

        #expect(draft.options.filters.map(\.ref) == ["tier-VIC", "created-since"])
    }

    @Test("A ref no longer offered, or a value asking for no day, changes nothing")
    func dayForAnUnknownRefChangesNothing() throws {
        let day = try #require(Date(calendarDay: "2026-07-01"))
        var draft = ClientFilterDraft(options: ClientSearchOptions(filters: [.value(ref: "tier-VIC")]))

        draft.pick(day, forValue: "created-gone", in: [Self.tier, Self.created])
        draft.pick(day, forValue: "created-last3Months", in: [Self.tier, Self.created])

        #expect(draft.options.filters == [.value(ref: "tier-VIC")])
    }

    @Test("A value asks for its day while it asks for one and is not picked")
    func needsDayUntilPicked() {
        let created = Self.created
        let since = created.values[2]
        var draft = ClientFilterDraft()

        #expect(draft.needsDay(for: since))
        #expect(!draft.needsDay(for: created.values[0]))

        draft.pick(since, of: created, parameters: ["since": "2026-07-01"])

        #expect(!draft.needsDay(for: since))
    }

    @Test("A touch picks a value, a second one lets go of it")
    func togglePicksThenLetsGo() {
        let tier = Self.tier
        var draft = ClientFilterDraft()

        draft.toggle(tier.values[0], of: tier)
        draft.toggle(tier.values[1], of: tier)
        #expect(draft.options.filters.map(\.ref) == ["tier-VIC", "tier-VIP"])

        draft.toggle(tier.values[0], of: tier)
        #expect(draft.options.filters.map(\.ref) == ["tier-VIP"])
    }

    @Test("A touch on a value of a single filter lets go of the one it had")
    func toggleKeepsTheSingleRule() {
        let created = Self.created
        var draft = ClientFilterDraft()
        draft.toggle(created.values[0], of: created)

        draft.toggle(created.values[1], of: created)

        #expect(draft.options.filters.map(\.ref) == ["created-last6Months"])
    }

    @Test("A touch never picks a value without the day it asks for; picked with its day, a touch lets go of it")
    func toggleNeverPicksWithoutItsDay() {
        let created = Self.created
        let since = created.values[2]
        var draft = ClientFilterDraft()

        draft.toggle(since, of: created)
        #expect(draft.options.filters.isEmpty)

        draft.pick(since, of: created, parameters: ["since": "2026-07-01"])
        draft.toggle(since, of: created)
        #expect(draft.options.filters.isEmpty)
    }

    @Test("A filter counts its own values picked: not another filter's, not a sentence's pills")
    func pickedCountIsTheFiltersOwn() {
        let tier = Self.tier
        let created = Self.created
        var draft = ClientFilterDraft()
        #expect(draft.pickedCount(in: tier) == 0)

        draft.pick(tier.values[0], of: tier)
        draft.pick(tier.values[1], of: tier)
        draft.pick(created.values[0], of: created)
        draft.receive(Self.answer([Self.pill("VIC")]))

        #expect(draft.pickedCount(in: tier) == 2)
        #expect(draft.pickedCount(in: created) == 1)
    }

    // MARK: - Pills

    @Test("A new sentence's filters take the place of the last one's pills, and leave the ticks")
    func receiveKeepsTheTicks() {
        let tier = Self.tier
        let vip = Self.pill("Clients VIP")
        let optOut = Self.pill("Sans opt-in email")
        var draft = ClientFilterDraft()
        draft.pick(tier.values[0], of: tier)
        draft.receive(Self.answer([vip]))

        draft.receive(Self.answer([optOut]))

        #expect(draft.filterItems == [optOut])
        #expect(draft.isPicked(tier.values[0]))
    }

    @Test("Removing a pill takes off that one only, found by its id: two pills may read alike")
    func removeTakesOffThatPillOnly() {
        let first = Self.pill("Clients VIP")
        let twin = Self.pill("Clients VIP")
        var draft = ClientFilterDraft()
        draft.receive(Self.answer([first, twin]))

        draft.remove(first)

        #expect(draft.filterItems == [twin])
    }

    @Test("A pill is never taken for a value of the tenant's filters")
    func pillIsNeverAPickedValue() {
        let tier = Self.tier
        var draft = ClientFilterDraft()

        draft.receive(Self.answer([Self.pill("VIC")]))

        #expect(!draft.isPicked(tier.values[0]))
        #expect(!draft.isPicked(tier.values[1]))
    }

    @Test("Ticking a value of a single filter lets go of the one it had, never of a pill")
    func singleKeepsThePills() {
        let created = Self.created
        let vip = Self.pill("Clients VIP")
        var draft = ClientFilterDraft()
        draft.pick(created.values[0], of: created)
        draft.receive(Self.answer([vip]))

        draft.pick(created.values[1], of: created)

        #expect(draft.filterItems == [vip])
        #expect(draft.options.filters.compactMap(\.ref) == ["created-last6Months"])
    }

    // MARK: - Sentence

    @Test("Words can be sent, never spaces and line breaks alone")
    func sendsWordsOnly() {
        #expect(ClientFilterDraft(text: "VIP clients").canSend)
        #expect(!ClientFilterDraft(text: "").canSend)
        #expect(!ClientFilterDraft(text: "  \n ").canSend)
    }

    @Test("Sending sends the sentence trimmed, leaves it in the field, and drops the last failure")
    func sendTrimsAndDropsFailure() {
        var draft = ClientFilterDraft(text: "  VIP clients\n", failure: "Couldn't read the sentence. Try again.")

        draft.send()

        #expect(draft.pendingText == "VIP clients")
        #expect(draft.text == "  VIP clients\n")
        #expect(draft.failure == nil)
        #expect(draft.hasPendingText)
        #expect(!draft.canSend)
    }

    @Test("Once its filters are back, the same sentence is not sent again, trimmed or not; changed, it is")
    func receivedTextIsNotSentAgain() {
        var draft = ClientFilterDraft(text: "VIP clients")
        draft.send()

        draft.receive(Self.answer([Self.pill("Clients VIP")], notUnderstood: ["last spring"]))

        #expect(!draft.hasPendingText)
        #expect(draft.notUnderstood == ["last spring"])
        #expect(!draft.canSend)
        draft.text = " VIP clients\n"
        #expect(!draft.canSend)
        draft.text = "VIP clients in Paris"
        #expect(draft.canSend)
    }

    @Test("Removing a pill lets the same sentence be sent again, to bring it back")
    func removeLetsTheTextBeSentAgain() {
        let vip = Self.pill("Clients VIP")
        var draft = ClientFilterDraft(text: "VIP clients")
        draft.send()
        draft.receive(Self.answer([vip]))

        draft.remove(vip)

        #expect(draft.canSend)
    }

    @Test("A failure leaves the pills as they were, and the sentence can be sent again")
    func failKeepsThePills() {
        let vip = Self.pill("Clients VIP")
        var draft = ClientFilterDraft(text: "VIP clients")
        draft.send()
        draft.receive(Self.answer([vip]))
        draft.text = "VIP clients in Paris"
        draft.send()

        draft.fail("Couldn't read the sentence. Try again.")

        #expect(!draft.hasPendingText)
        #expect(draft.failure == "Couldn't read the sentence. Try again.")
        #expect(draft.filterItems == [vip])
        #expect(draft.canSend)
    }

    // MARK: - Clear

    @Test("A sort picked, filters, or what the last answer said, are something to clear; a sentence alone is not")
    func canClear() {
        var sorted = ClientSearchOptions()
        sorted.pick(Self.lastPurchase)

        #expect(!ClientFilterDraft(text: "VIP clients", lastFetched: "VIP clients").canClear)
        #expect(ClientFilterDraft(options: sorted).canClear)
        #expect(ClientFilterDraft(options: ClientSearchOptions(filters: [.value(ref: "a")])).canClear)
        #expect(ClientFilterDraft(notUnderstood: ["last spring"]).canClear)
        #expect(ClientFilterDraft(failure: "Couldn't read the sentence. Try again.").canClear)
    }

    @Test("Clearing puts the server's default sort back: no sort is sent, the default one is ticked")
    func clearPutsTheDefaultSortBack() {
        var options = ClientSearchOptions()
        options.pick(Self.lastPurchase)
        var draft = ClientFilterDraft(options: options)

        draft.clear()

        #expect(draft.options.sortBy == nil)
        #expect(draft.options.direction == nil)
        #expect(draft.options.isPicked(Self.name))
        #expect(!draft.options.isPicked(Self.lastPurchase))
    }

    @Test("Clearing takes every filter off with what the last answer said; the field and a sentence on its way stay")
    func clearKeepsTheFieldAndTheRequest() {
        var draft = ClientFilterDraft(
            options: ClientSearchOptions(filters: [.value(ref: "a"), .filter(Self.pill("Clients VIP"))]),
            text: "VIP clients in Paris",
            pendingText: "VIP clients in Paris",
            lastFetched: "VIP clients",
            notUnderstood: ["last spring"],
            failure: "Couldn't read the sentence. Try again."
        )

        draft.clear()

        #expect(draft == ClientFilterDraft(text: "VIP clients in Paris", pendingText: "VIP clients in Paris"))
    }

    // MARK: - Helpers

    /// Two segments, any number of them picked. Computed, a fresh one each
    /// time: a `@Model` is not `Sendable`, so it cannot sit in a static stored
    /// property.
    private static var tier: ClientFilter {
        ClientFilter(id: "tier", titleKey: "client.filter.tier", selectionRaw: "MULTIPLE", rank: 0, values: [
            ClientFilterValue(ref: "tier-VIC", labelKey: nil, label: "VIC", parameters: []),
            ClientFilterValue(ref: "tier-VIP", labelKey: nil, label: "VIP", parameters: []),
        ])
    }
    /// One value at a time: two windows, then "Since a date".
    private static var created: ClientFilter {
        ClientFilter(id: "created", titleKey: "client.filter.created", selectionRaw: "SINGLE", rank: 1, values: [
            ClientFilterValue(
                ref: "created-last3Months", labelKey: "client.filter.value.last3Months", label: nil, parameters: []
            ),
            ClientFilterValue(
                ref: "created-last6Months", labelKey: "client.filter.value.last6Months", label: nil, parameters: []
            ),
            ClientFilterValue(
                ref: "created-since", labelKey: "client.filter.value.since", label: nil,
                parameters: [ClientFilterValue.Parameter(name: "since", typeRaw: "date")]
            ),
        ])
    }

    /// The server's default sort, and another one.
    private static var name: ClientSort {
        ClientSort(value: "name", labelKey: "client.sort.name", directionRaw: "asc", isDefault: true, rank: 0)
    }
    private static var lastPurchase: ClientSort {
        ClientSort(
            value: "lastPurchase", labelKey: "client.sort.lastPurchase", directionRaw: "desc", isDefault: false, rank: 1
        )
    }

    /// A pill as a sentence's filters give it, a new one at each call; its
    /// condition is never read here.
    private static func pill(_ label: String) -> ClientFilterItem {
        ClientFilterItem(label: label, condition: .object(["field": .string("client.segment")]))
    }

    /// The server's answer for a sentence: `items` as pills, and the words no
    /// filter covers.
    private static func answer(_ items: [ClientFilterItem], notUnderstood: [String] = []) -> ClientFilterItems {
        ClientFilterItems(items: items, notUnderstood: notUnderstood)
    }
}
