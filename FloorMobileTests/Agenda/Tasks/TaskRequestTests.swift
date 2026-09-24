//
//  TaskRequestTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Task request")
struct TaskRequestTests {

    private static func moment(_ hour: Int, _ minute: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return try #require(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 17, hour: hour, minute: minute)
        ))
    }

    /// The JSON as the API will actually receive it — the same encoder
    /// `APIClient` uses, so a key dropped here is a key dropped on the wire.
    private static func encoded(_ request: TaskRequest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try JSONSerialization.jsonObject(with: try encoder.encode(request))
        return try #require(object as? [String: Any])
    }

    // MARK: - Mapping

    @Test("The form's fields land on the server's own names")
    func draftMapsOntoTheWireFields() throws {
        let due = try Self.moment(10)
        var draft = TaskDraft(day: due)
        draft.title = "Rappeler Mme Dupont"
        draft.reason = .birthday
        draft.note = "Relance suite essayage"

        let request = TaskRequest(draft: draft)

        #expect(request.title == "Rappeler Mme Dupont")
        #expect(request.reason == "BIRTHDAY")
        #expect(request.startDate == due)
        #expect(request.description == "Relance suite essayage")
        #expect(request.status == "TO_DO")
    }

    @Test("What the form does not show is carried back untouched")
    func serverOwnedFieldsSurviveAnEdit() throws {
        let reminder = try Self.moment(9)
        var draft = TaskDraft(task: AgendaTask(
            id: "t1", statusRaw: "COMPLETED", reasonRaw: "FOLLOW_UP", title: "Ring back",
            startDate: try Self.moment(10), reminderDate: reminder,
            createdAt: .now, updatedAt: .now
        ))
        draft.title = "Ring back this afternoon"

        let request = TaskRequest(draft: draft)

        #expect(request.status == "COMPLETED")
        #expect(request.reminderDate == reminder)
    }

    /// A reason `Reason` does not know lands on `.other`, which encodes as
    /// "OTHER" — so editing anything else about the task would rewrite it.
    @Test("A reason this app does not know reaches the request as it came")
    func unknownReasonIsPreserved() throws {
        var draft = TaskDraft(task: AgendaTask(
            id: "t1", statusRaw: "TO_DO", reasonRaw: "CALL", title: "Ring back",
            startDate: try Self.moment(10), createdAt: .now, updatedAt: .now
        ))
        draft.title = "Ring back this afternoon"

        let request = TaskRequest(draft: draft)

        #expect(request.reason == "CALL")
    }

    @Test("The title is sent trimmed — what was judged is what is saved")
    func titleIsSentTrimmed() throws {
        var draft = TaskDraft(day: try Self.moment(10))
        draft.title = "  Rappeler Mme Dupont  "

        #expect(TaskRequest(draft: draft).title == "Rappeler Mme Dupont")
    }

    // MARK: - Encoded shape

    @Test("An empty note drops the key rather than sending an empty string")
    func blankNoteIsAbsentFromTheJSON() throws {
        var draft = TaskDraft(day: try Self.moment(10))
        draft.title = "Rappeler Mme Dupont"
        draft.note = "   \n "

        let json = try Self.encoded(TaskRequest(draft: draft))

        #expect(json["description"] == nil)
        #expect(json["reminderDate"] == nil)
    }

    /// Until the Clients feature lands the picker holds a name, not an id, and
    /// a `clientId` the app invented would be worse than none.
    @Test("No client id is ever sent, and the client's name never leaks into the body")
    func clientIsAbsentFromTheJSON() throws {
        var draft = TaskDraft(day: try Self.moment(10))
        draft.title = "Rappeler Mme Dupont"
        draft.clientName = "Raphaël Van den Berg"

        let json = try Self.encoded(TaskRequest(draft: draft))

        #expect(json["clientId"] == nil)
        #expect(json["clientName"] == nil)
        // The whole body, named. No `reason`: nobody picked one, and the key
        // is dropped rather than sent as null. No `type` either — the task
        // routes have no such field, and this route rejects a key it did not
        // ask for.
        #expect(Set(json.keys) == ["title", "status", "startDate"])

        // And it does appear once someone picks one.
        draft.reason = .followUp
        #expect(try Self.encoded(TaskRequest(draft: draft))["reason"] as? String == "FOLLOW_UP")
    }

    @Test("Dates go out as ISO 8601")
    func datesAreISO8601() throws {
        var draft = TaskDraft(day: try Self.moment(10))
        draft.title = "Rappeler Mme Dupont"
        draft.reminderDate = try Self.moment(9)

        let json = try Self.encoded(TaskRequest(draft: draft))

        // Europe/Paris in September is UTC+2.
        #expect(json["startDate"] as? String == "2026-09-17T08:00:00Z")
        #expect(json["reminderDate"] as? String == "2026-09-17T07:00:00Z")
    }
}
