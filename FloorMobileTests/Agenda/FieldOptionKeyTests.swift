//
//  FieldOptionKeyTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

/// The keys the agenda reads `GET enums` by, checked against a real payload.
///
/// This suite exists because the failure it catches is silent. When the server
/// renames a field — `event.type` became `event.meetingType` — the store simply
/// holds nothing under the old name, `resolved(fallback:)` politely returns the
/// local list, and the picker goes on working with a vocabulary the backend
/// stopped publishing. Good behaviour at runtime, and exactly the kind of quiet
/// a test has to break.
@Suite("Vocabulary keys")
struct FieldOptionKeyTests {

    /// Every key the agenda declares, with the name it goes by in prose.
    private static let declared: [(name: String, key: FieldOption.Key)] = [
        ("taskReason", .taskReason),
        ("eventReason", .eventReason),
        ("taskStatus", .taskStatus),
        ("eventStatus", .eventStatus),
        ("eventMeetingType", .eventMeetingType),
    ]

    private static func payload() throws -> EnumsPayload {
        try JSONDecoder().decode(EnumsPayload.self, from: Fixture.data("enums"))
    }

    @Test("Every declared key names a field the server actually publishes")
    func everyKeyResolvesInThePayload() throws {
        let payload = try Self.payload()

        for (name, key) in Self.declared {
            let values = payload[key.entityName]?[key.field]
            #expect(
                values?.isEmpty == false,
                "\(name) points at \(key.entityName).\(key.field), which the payload does not publish"
            )
        }
    }

    @Test("A key the server does not publish is caught rather than silently empty")
    func aRenamedFieldWouldBeCaught() throws {
        let payload = try Self.payload()

        // The name this field used to go by. Left here deliberately: it is the
        // shape of the mistake this suite is for.
        #expect(payload["event"]?["type"] == nil)
        #expect(payload["event"]?["meetingType"]?.isEmpty == false)
    }

    @Test("Each key stays on its own entity, so the two vocabularies never merge")
    func keysAreScopedToTheirEntity() {
        #expect(FieldOption.Key.taskReason.entityName == "task")
        #expect(FieldOption.Key.eventReason.entityName == "event")
        #expect(FieldOption.Key.taskReason.field == FieldOption.Key.eventReason.field)
        // Same field name, different entity — the pair is what identifies a
        // vocabulary, never the field alone.
        #expect(FieldOption.Key.taskReason != FieldOption.Key.eventReason)
    }

    @Test("The values behind each key are ones this build can name")
    func publishedValuesResolveToLocalEnums() throws {
        let payload = try Self.payload()

        func options(_ key: FieldOption.Key) -> [FieldOption] {
            FieldOptionDTO.rows(from: payload)
                .filter { $0.entityName == key.entityName && $0.field == key.field }
                .map(FieldOption.init(dto:))
        }

        // `resolved` drops what it cannot name and falls back when it can name
        // nothing — so a result equal to the fallback means the whole published
        // list went unrecognised.
        let reasons = options(.taskReason).resolved(fallback: [Reason.other])
        #expect(reasons != [Reason.other])

        let meetingTypes = options(.eventMeetingType).resolved(fallback: [MeetingType.other])
        #expect(meetingTypes == [.inPerson, .videoCall])

        let taskStatuses = options(.taskStatus).resolved(fallback: [TaskStatus.other])
        #expect(taskStatuses == [.toDo, .completed, .canceled])
    }
}
