//
//  DraftTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("Drafts")
struct DraftTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendar
    }()

    private static func moment(_ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(Self.calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 7, hour: hour, minute: minute)
        ))
    }

    // MARK: - Validity

    @Test("A draft with no title cannot be confirmed", arguments: ["", " ", "\n", "   \t  "])
    func blankTitlesAreInvalid(title: String) throws {
        var task = TaskDraft(day: try Self.moment(9))
        task.title = title
        #expect(!task.isValid)

        var event = EventDraft(day: try Self.moment(9))
        event.title = title
        #expect(!event.isValid)
    }

    @Test("A title is enough — everything else has a sensible default")
    func titleAloneValidates() throws {
        var task = TaskDraft(day: try Self.moment(9))
        task.title = "Call about the Solène order"
        // No client, no note: those are not required to file a task.
        #expect(task.clientName.isEmpty)
        #expect(task.isValid)

        var event = EventDraft(day: try Self.moment(9))
        event.title = "Autumn fitting"
        #expect(event.isValid)
    }

    @Test("Surrounding whitespace does not make a title")
    func titleIsTrimmedBeforeJudging() throws {
        var task = TaskDraft(day: try Self.moment(9))
        task.title = "  Call her back  "
        #expect(task.isValid)
        // And what is sent is what was judged, not the raw field.
        #expect(task.trimmedTitle == "Call her back")
    }

    // MARK: - Seeding

    @Test("A draft starts on the day the agenda was showing, not today")
    func seededWithTheBrowsedDay() throws {
        let tuesday = try Self.moment(0)
        #expect(TaskDraft(day: tuesday).dueDate == tuesday)
        #expect(EventDraft(day: tuesday).startDate == tuesday)
    }

    // MARK: - Seeding from an existing row

    @Test("A task's draft opens on the task's own values")
    func taskDraftMirrorsTheTask() throws {
        let due = try Self.moment(11, 15)
        let reminder = try Self.moment(9)
        let draft = TaskDraft(task: AgendaTask(
            id: "t1", statusRaw: "COMPLETED", reasonRaw: "BIRTHDAY",
            title: "Call about the Solène order",
            taskDescription: "She asked for the ivory one",
            startDate: due, reminderDate: reminder,
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Léa", lastName: "Bonnet")
        ))

        #expect(draft.id == "t1")
        #expect(draft.title == "Call about the Solène order")
        #expect(draft.reason == .birthday)
        #expect(draft.clientName == "Léa Bonnet")
        #expect(draft.dueDate == due)
        #expect(draft.note == "She asked for the ivory one")
        // The form shows neither of these two, so a save must carry them back
        // untouched — a closed task must not reopen because a title changed.
        #expect(draft.status == "COMPLETED")
        #expect(draft.reminderDate == reminder)
    }

    @Test("A new draft has no id, the server's default status, and no reminder")
    func newDraftCarriesTheCreationDefaults() throws {
        let draft = TaskDraft(day: try Self.moment(9))

        #expect(draft.id == nil)
        #expect(draft.status == "TO_DO")
        #expect(draft.reminderDate == nil)
    }

    @Test("What the API left out becomes an empty field, not a literal nil")
    func taskDraftFillsTheGapsWithEmptyText() throws {
        let draft = TaskDraft(task: AgendaTask(
            id: "t2", statusRaw: "TO_DO", reasonRaw: "FOLLOW_UP", title: "Ring back",
            startDate: try Self.moment(9), createdAt: .now, updatedAt: .now
        ))

        #expect(draft.clientName.isEmpty)
        #expect(draft.note.isEmpty)
    }

    @Test("An appointment's draft opens on the appointment's own values")
    func eventDraftMirrorsTheEvent() throws {
        let start = try Self.moment(14, 30)
        let draft = EventDraft(event: AgendaEvent(
            id: "e1", statusRaw: "CONFIRMED", reasonRaw: "VIP_EVENT",
            meetingTypeRaw: "VIDEO_CALL", title: "Autumn fitting",
            eventDescription: "Bring the two coats",
            startDate: start, duration: 90,
            reminderDate: start.addingTimeInterval(-15 * 60),
            createdAt: .now, updatedAt: .now,
            client: ClientSummary(firstName: "Salomé", lastName: "Kaliny")
        ))

        #expect(draft.id == "e1")
        #expect(draft.title == "Autumn fitting")
        #expect(draft.reason == .vipEvent)
        #expect(draft.meetingType == .videoCall)
        #expect(draft.clientName == "Salomé Kaliny")
        #expect(draft.startDate == start)
        #expect(draft.duration == 90)
        #expect(draft.reminderOffset == 15)
        #expect(draft.note == "Bring the two coats")
        // The form has no status field, so a save has to carry this back.
        #expect(draft.status == "CONFIRMED")
    }

    @Test("A new appointment has no id and the default booking status")
    func newEventDraftCarriesTheCreationDefaults() throws {
        let draft = EventDraft(day: try Self.moment(9))

        #expect(draft.id == nil)
        #expect(draft.status == "PLANNED")
    }

    /// `Reason` lands every value it does not know on `.other`, which encodes
    /// as "OTHER" — so an untouched reason has to go back as it came.
    @Test("A reason this app does not know survives an edit, on both forms")
    func unknownReasonIsPreserved() throws {
        var task = TaskDraft(task: AgendaTask(
            id: "t1", statusRaw: "TO_DO", reasonRaw: "CALL", title: "Ring back",
            startDate: try Self.moment(9), createdAt: .now, updatedAt: .now
        ))
        #expect(task.reason == .other)
        #expect(task.reasonRaw == "CALL")
        task.reason = .birthday
        #expect(task.reasonRaw == "BIRTHDAY")

        var event = EventDraft(event: AgendaEvent(
            id: "e1", statusRaw: "PLANNED", reasonRaw: "STORE_ANNIVERSARY", title: "Fitting",
            startDate: try Self.moment(9), duration: 30, createdAt: .now, updatedAt: .now
        ))
        #expect(event.reasonRaw == "STORE_ANNIVERSARY")
        event.reason = .followUp
        #expect(event.reasonRaw == "FOLLOW_UP")
    }

    @Test("A new draft sends no reason until one is picked")
    func newDraftSendsThePickedReason() throws {
        var task = TaskDraft(day: try Self.moment(9))
        // Neither a guess nor "OTHER": the field is unanswered, and the API
        // does not require an answer.
        #expect(task.reason == nil)
        #expect(task.reasonRaw == nil)
        task.reason = .vipEvent
        #expect(task.reasonRaw == "VIP_EVENT")

        #expect(EventDraft(day: try Self.moment(9)).reasonRaw == nil)
    }

    // MARK: - The hour a new appointment starts on

    @Test("On today, a new appointment starts at the next whole hour")
    func defaultStartRoundsUpToday() throws {
        let now = try Self.moment(11, 50)
        #expect(EventDraft.defaultStart(on: now, now: now, calendar: Self.calendar)
            == (try Self.moment(12)))
    }

    @Test("Already on the hour, it still moves on")
    func defaultStartMovesOnFromAWholeHour() throws {
        let now = try Self.moment(12)
        #expect(EventDraft.defaultStart(on: now, now: now, calendar: Self.calendar)
            == (try Self.moment(13)))
    }

    @Test("Any other day opens the shop rather than booking one past midnight")
    func defaultStartOpensTheShopOnOtherDays() throws {
        let tuesday = try #require(Self.calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 29)
        ))
        let start = EventDraft.defaultStart(
            on: tuesday, now: try Self.moment(11, 50), calendar: Self.calendar
        )
        #expect(Self.calendar.component(.day, from: start) == 29)
        // Read off the type rather than written as 9: change the opening hour
        // and the test follows instead of breaking.
        #expect(Self.calendar.component(.hour, from: start) == EventDraft.defaultStartHour)
    }

    /// The offset is what the form edits and the date is what the API stores,
    /// so the pair has to survive the round trip unchanged.
    @Test(
        "The reminder date comes back as the offset that produced it",
        arguments: ReminderOffset.selectable.compactMap { $0 }
    )
    func reminderOffsetSurvivesTheRoundTrip(offset: Int) throws {
        let start = try Self.moment(14)
        var sent = EventDraft(day: start)
        sent.reminderOffset = offset

        let draft = EventDraft(event: try Self.event(start: start, reminderDate: sent.reminderDate))
        #expect(draft.reminderOffset == offset)
    }

    @Test("A reminder the API never set leaves the form on 'None'")
    func noReminderDateMeansNoOffset() throws {
        let draft = EventDraft(event: try Self.event(start: try Self.moment(14), reminderDate: nil))
        #expect(draft.reminderOffset == nil)
    }

    /// A reminder at or past the start is no offset anyone picked in this form;
    /// showing "0 min before" — or a negative one — would be reading it wrong.
    @Test("A reminder that does not precede the start is not an offset")
    func reminderAtOrAfterTheStartIsIgnored() throws {
        let start = try Self.moment(14)
        #expect(EventDraft(event: try Self.event(start: start, reminderDate: start)).reminderOffset == nil)
        #expect(EventDraft(
            event: try Self.event(start: start, reminderDate: start.addingTimeInterval(10 * 60))
        ).reminderOffset == nil)
    }

    @Test("An appointment with no meeting type opens without one")
    func missingMeetingTypeStaysUnset() throws {
        let draft = EventDraft(event: AgendaEvent(
            id: "e2", statusRaw: "PLANNED", reasonRaw: "FOLLOW_UP", title: "Fitting",
            startDate: try Self.moment(14), duration: 60, createdAt: .now, updatedAt: .now
        ))
        // Opening the form must not invent a type: saving would write it in.
        #expect(draft.meetingType == nil)
    }

    private static func event(start: Date, reminderDate: Date?) throws -> AgendaEvent {
        AgendaEvent(
            id: "e", statusRaw: "PLANNED", reasonRaw: "FOLLOW_UP", title: "Fitting",
            startDate: start, duration: 60, reminderDate: reminderDate,
            createdAt: .now, updatedAt: .now
        )
    }

    // MARK: - Picker options

    /// The form's lists are fixed, the rows it edits are not: a value the list
    /// does not offer must widen it, or the `Picker` draws an empty row and
    /// the first tap rewrites the field.
    @Test("An unoffered value joins the list; an offered one does not repeat")
    func optionsMakeRoomForTheValueBeingEdited() {
        #expect(EventDraft.durations.including(45).sorted() == [15, 30, 45, 60, 90, 120])
        #expect(EventDraft.durations.including(60) == EventDraft.durations)
        #expect(ReminderOffset.selectable.including(20) == [nil, 5, 15, 30, 60, 20])
        #expect(ReminderOffset.selectable.including(nil) == ReminderOffset.selectable)
    }

    // MARK: - Reminder

    /// Driven by the offsets the picker actually offers, so dropping one from
    /// the list drops it from the test with it.
    @Test("The reminder offset becomes the instant the API stores", arguments: ReminderOffset.selectable.compactMap { $0 })
    func reminderDateIsDerivedFromTheOffset(offset: Int) throws {
        var draft = EventDraft(day: try Self.moment(14))
        draft.startDate = try Self.moment(14)
        draft.reminderOffset = offset

        let expected = try Self.moment(14).addingTimeInterval(-Double(offset) * 60)
        #expect(draft.reminderDate == expected)
    }

    @Test("No offset, no reminder date — the API gets nil rather than the start")
    func noReminderMeansNoDate() throws {
        var draft = EventDraft(day: try Self.moment(14))
        draft.reminderOffset = nil
        #expect(draft.reminderDate == nil)
    }

    @Test("An offset that crosses midnight lands on the day before")
    func reminderCanFallOnThePreviousDay() throws {
        var draft = EventDraft(day: try Self.moment(0, 30))
        draft.startDate = try Self.moment(0, 30)
        // An hour before half past midnight is half past eleven, the night
        // before — the arithmetic must not clamp to the start of the day.
        draft.reminderOffset = 60

        let reminder = try #require(draft.reminderDate)
        #expect(Self.calendar.component(.day, from: reminder) == 6)
        #expect(Self.calendar.component(.hour, from: reminder) == 23)
        #expect(Self.calendar.component(.minute, from: reminder) == 30)
    }
}
