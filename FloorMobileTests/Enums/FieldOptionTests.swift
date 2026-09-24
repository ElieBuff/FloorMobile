//
//  FieldOptionTests.swift
//  FloorMobileTests
//

import Foundation
import SwiftData
import Testing
@testable import FloorMobile

@Suite("FieldOption vocabulary")
@MainActor
struct FieldOptionTests {

    @Test("The payload flattens into one row per value, keeping the server's order")
    func flattensPayload() throws {
        let payload = try JSONDecoder().decode(EnumsPayload.self, from: Fixture.data("enums"))

        let rows = FieldOptionDTO.rows(from: payload)

        // One row per value, nothing lost and nothing invented.
        let valueCount = try Fixture.enumsValueCount()
        #expect(rows.count == valueCount)

        // Entities *and* fields are sorted, so the flattening never depends on
        // dictionary ordering. Stated as the invariant rather than as fixed
        // positions, which move the moment the payload gains a field.
        let keys = rows.map { "\($0.entityName).\($0.field)" }
        #expect(keys == keys.sorted())

        let taskReasons = rows.filter { $0.entityName == "task" && $0.field == "reason" }
        #expect(taskReasons.map(\.value) == [
            "BIRTHDAY", "BACK_IN_STOCK", "COLLECTION_LAUNCH",
            "VIP_EVENT", "FOLLOW_UP", "WISHLIST_AVAILABLE",
        ])
        // The rank mirrors the server's own order, not the alphabet.
        #expect(taskReasons.map(\.rank) == Array(0 ..< 6))
    }

    @Test("An entity or field the app knows nothing about still lands in the store")
    func carriesUnknownFields() throws {
        let json = Data(#"{"client": {"segment": ["VIC", "GOLD"]}}"#.utf8)
        let payload = try JSONDecoder().decode(EnumsPayload.self, from: json)

        let rows = FieldOptionDTO.rows(from: payload)

        #expect(rows.map(\.value) == ["VIC", "GOLD"])
        #expect(rows.allSatisfy { $0.entityName == "client" && $0.field == "segment" })
    }

    @Test("A key's descriptor returns only its own field, in rank order")
    func descriptorFiltersAndSorts() throws {
        let container = try ModelContainer(
            for: FieldOption.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(FieldOption(entityName: "task", field: "reason", value: "SECOND", rank: 1))
        context.insert(FieldOption(entityName: "task", field: "reason", value: "FIRST", rank: 0))
        context.insert(FieldOption(entityName: "event", field: "reason", value: "ELSEWHERE", rank: 0))
        try context.save()

        let options = try context.fetch(FieldOption.descriptor(for: .taskReason))

        #expect(options.map(\.value) == ["FIRST", "SECOND"])
    }

    // MARK: - Resolving to the local enums

    @Test("A field's stored values become the enum a picker offers, in the server's order")
    func resolvesToLocalEnum() throws {
        let payload = try JSONDecoder().decode(EnumsPayload.self, from: Fixture.data("enums"))
        let options = FieldOptionDTO.rows(from: payload)
            .filter { $0.entityName == "event" && $0.field == "meetingType" }
            .map(FieldOption.init(dto:))

        #expect(options.resolved(fallback: MeetingType.selectable) == [.inPerson, .videoCall])
    }

    @Test("A value this build does not know is dropped rather than shown blank")
    func dropsUnknownValues() {
        let options = [
            FieldOption(entityName: "task", field: "reason", value: "FOLLOW_UP", rank: 0),
            FieldOption(entityName: "task", field: "reason", value: "STORE_VISIT", rank: 1),
        ]

        // `STORE_VISIT` still decodes on a record — as `.other` — it simply
        // cannot be picked until a release has a label and an icon for it.
        #expect(options.resolved(fallback: Reason.selectable) == [.followUp])
        #expect(Reason(raw: "STORE_VISIT") == .other)
    }

    @Test("An empty store falls back to the local list rather than an empty picker")
    func fallsBackWhenEmpty() {
        let none: [FieldOption] = []

        #expect(none.resolved(fallback: Reason.selectable) == Reason.selectable)
        #expect(none.resolved(fallback: MeetingType.selectable) == [.inPerson, .videoCall])
    }

    @Test("A field of values the build knows nothing about falls back too")
    func fallsBackWhenNothingIsKnown() {
        let options = [FieldOption(entityName: "task", field: "reason", value: "STORE_VISIT", rank: 0)]

        #expect(options.resolved(fallback: Reason.selectable) == Reason.selectable)
    }

    @Test("`other` is never offered — it is where unknown values land, not a choice")
    func otherIsNotSelectable() {
        #expect(!Reason.selectable.contains(.other))
        #expect(!MeetingType.selectable.contains(.other))
        // And the server does not send it either, which is the same statement
        // made twice on purpose: the day it does, this test says so.
        #expect(Reason.selectable.count == Reason.allCases.count - 1)
    }
}
