//
//  EventRequestTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Event request")
struct EventRequestTests {

    private static func moment(_ hour: Int, _ minute: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 17, hour: hour, minute: minute)
        ))
    }

    /// The JSON as the API will actually receive it — the same encoder
    /// `APIClient` uses, so a key dropped here is a key dropped on the wire.
    private static func encoded(_ request: EventRequest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: try encoder.encode(request))
        return try #require(object as? [String: Any])
    }

    private static func draft(title: String = "Essayage collection automne") throws -> EventDraft {
        var draft = EventDraft(day: try moment(20, 30))
        draft.title = title
        draft.reason = .backInStock
        draft.meetingType = .inPerson
        draft.duration = 45
        draft.note = "RDV essayage"
        return draft
    }

    // MARK: - Mapping

    @Test("The form's fields land on the server's own names")
    func draftMapsOntoTheWireFields() throws {
        let start = try Self.moment(20, 30)
        let request = EventRequest(draft: try Self.draft())

        #expect(request.title == "Essayage collection automne")
        #expect(request.reason == "BACK_IN_STOCK")
        #expect(request.meetingType == "IN_PERSON")
        #expect(request.startDate == start)
        #expect(request.duration == 45)
        #expect(request.description == "RDV essayage")
        #expect(request.status == "PLANNED")
    }

    /// The meeting type goes out under one name only. `createEventSchema` and
    /// `updateEventSchema` are `.strict()` and declare `meetingType` alone, so
    /// a spare `type` key is a *rejected* request, not an ignored one — which
    /// is what the app used to send, back when `GET enums` published the
    /// vocabulary under `event.type`. Pinned here rather than left to the keys
    /// test below, because the failure mode is a 400 on every save.
    @Test("The meeting type goes out as `meetingType`, with no `type` beside it")
    func meetingTypeIsTheOnlyTypeField() throws {
        var draft = try Self.draft()
        draft.meetingType = .videoCall

        let json = try Self.encoded(EventRequest(draft: draft))

        #expect(json["meetingType"] as? String == "VIDEO_CALL")
        #expect(json["type"] == nil)
    }

    @Test("The reminder goes out as the instant it fires, not as the offset")
    func reminderOffsetBecomesADate() throws {
        var draft = try Self.draft()
        draft.reminderOffset = 30

        let expected = try Self.moment(20, 0)
        #expect(EventRequest(draft: draft).reminderDate == expected)
    }

    @Test("No reminder, no key at all")
    func noReminderIsAbsentFromTheJSON() throws {
        var draft = try Self.draft()
        draft.reminderOffset = nil
        draft.note = "  "

        let json = try Self.encoded(EventRequest(draft: draft))

        #expect(json["reminderDate"] == nil)
        #expect(json["description"] == nil)
    }

    @Test("What the form does not show is carried back untouched")
    func serverOwnedFieldsSurviveAnEdit() throws {
        var draft = EventDraft(event: AgendaEvent(
            id: "e1", statusRaw: "CANCELLED", reasonRaw: "FOLLOW_UP",
            meetingTypeRaw: "IN_PERSON", title: "Essayage",
            startDate: try Self.moment(20, 30), duration: 45,
            createdAt: .now, updatedAt: .now
        ))
        draft.title = "Essayage — reporté"

        #expect(EventRequest(draft: draft).status == "CANCELLED")
    }

    /// A reason `Reason` does not know lands on `.other`, which encodes as
    /// "OTHER" — so editing anything else about the event would rewrite it.
    @Test("A reason this app does not know goes back exactly as it came")
    func unknownReasonIsPreserved() throws {
        var draft = EventDraft(event: AgendaEvent(
            id: "e1", statusRaw: "PLANNED", reasonRaw: "STORE_ANNIVERSARY",
            title: "Essayage", startDate: try Self.moment(20, 30), duration: 45,
            createdAt: .now, updatedAt: .now
        ))
        #expect(draft.reason == .other)
        draft.duration = 60

        #expect(EventRequest(draft: draft).reason == "STORE_ANNIVERSARY")

        // But a reason actually picked in the form wins over the stored one.
        draft.reason = .birthday
        #expect(EventRequest(draft: draft).reason == "BIRTHDAY")
    }

    // MARK: - Encoded shape

    @Test("The title is sent trimmed — what was judged is what is saved")
    func titleIsSentTrimmed() throws {
        let request = EventRequest(draft: try Self.draft(title: "  Essayage  "))

        #expect(request.title == "Essayage")
    }

    /// Until the Clients feature lands the picker holds a name, not an id.
    @Test("No client id is ever sent, and the client's name never leaks into the body")
    func clientIsAbsentFromTheJSON() throws {
        var draft = try Self.draft()
        draft.clientName = "Raphaël Van den Berg"

        let json = try Self.encoded(EventRequest(draft: draft))

        #expect(json["clientId"] == nil)
        #expect(json["clientName"] == nil)
        #expect(Set(json.keys) == [
            "title", "status", "startDate",
            "description", "duration", "reminderDate", "meetingType", "reason",
        ])
    }

    @Test("Dates go out as ISO 8601")
    func datesAreISO8601() throws {
        let json = try Self.encoded(EventRequest(draft: try Self.draft()))

        // Europe/Paris in September is UTC+2.
        #expect(json["startDate"] as? String == "2026-09-17T18:30:00Z")
        #expect(json["reminderDate"] as? String == "2026-09-17T18:00:00Z")
    }
}
