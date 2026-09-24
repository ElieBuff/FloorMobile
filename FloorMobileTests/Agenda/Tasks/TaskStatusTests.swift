//
//  TaskStatusTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("TaskStatus")
struct TaskStatusTests {

    @Test("Every status the API sends round-trips through its raw value", arguments: TaskStatus.allCases)
    func rawValuesMap(status: TaskStatus) {
        #expect(TaskStatus(raw: status.rawValue) == status)
    }

    /// Spelled out rather than derived: these strings are the server's, and a
    /// test that reuses `rawValue` to check `rawValue` would pass through a
    /// rename that breaks every request.
    @Test("The wire spellings are the server's own")
    func wireSpellings() {
        #expect(TaskStatus(raw: "TO_DO") == .toDo)
        #expect(TaskStatus(raw: "COMPLETED") == .completed)
        #expect(TaskStatus(raw: "CANCELED") == .canceled)
    }

    /// The one that matters: the two entities do not spell cancellation alike,
    /// and aligning them "for consistency" would silently break one of them.
    @Test("A task is CANCELED with one L, an event CANCELLED with two")
    func cancellationIsSpelledDifferentlyPerEntity() {
        #expect(TaskStatus.canceled.rawValue == "CANCELED")
        #expect(EventStatus.cancelled.rawValue == "CANCELLED")
        #expect(TaskStatus.canceled.rawValue != EventStatus.cancelled.rawValue)
    }

    @Test("A new task starts as TO_DO, which is what a draft sends")
    func initialStatusIsWhatADraftSends() {
        #expect(TaskStatus.initial == .toDo)
        #expect(TaskDraft.defaultStatus == "TO_DO")
    }

    @Test(
        "A status this build has never heard of lands on `other`",
        arguments: ["TODO", "DONE", "IN_PROGRESS", "", "to_do"]
    )
    func unknownStatusesFallBack(raw: String) {
        #expect(TaskStatus(raw: raw) == .other)
    }

    // MARK: - What a day shows

    @Test("A day lists what is to do and what was done, and nothing else")
    func listedAdmitsWorkAndProof() {
        #expect(TaskStatus.listed == [.toDo, .completed])
        #expect(!TaskStatus.listed.contains(.canceled))
        // An allow-list, so a value this build cannot read is left out too.
        #expect(!TaskStatus.listed.contains(.other))
    }

    /// The order is the one the query's `IN` clause is built from, so it is
    /// pinned: `listed` is a stored constant, not a filter over `allCases`.
    @Test("The listed statuses carry the server's spellings")
    func listedCarriesWireSpellings() {
        #expect(TaskStatus.listed.map(\.rawValue) == ["TO_DO", "COMPLETED"])
    }

    // MARK: - The tick

    @Test("Ticking a task marks it done, and ticking a done task reopens it")
    func togglingRoundTrips() {
        #expect(TaskStatus.toDo.toggled == .completed)
        #expect(TaskStatus.completed.toggled == .toDo)
        // Two taps land back where they started.
        #expect(TaskStatus.toDo.toggled.toggled == .toDo)
    }

    /// The tick is two states over a four-state vocabulary: anything that is
    /// not "done" becomes done, rather than the tap doing nothing.
    @Test("A status the tick cannot represent becomes done", arguments: [TaskStatus.canceled, .other])
    func togglingAnUnrepresentedStatusCompletesIt(status: TaskStatus) {
        #expect(status.toggled == .completed)
    }
}
