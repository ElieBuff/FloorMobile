//
//  AgendaTaskTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AgendaTask wire format & mapping")
struct AgendaTaskTests {

    @Test("Decodes a page and flattens people and store into the model")
    func mapsFromDTO() throws {
        let page = try APIClient.makeDecoder()
            .decode(CursorPage<TaskDTO>.self, from: Fixture.data("task_agenda_page1"))

        #expect(!page.hasMore)
        #expect(page.nextCursor == nil)

        let dto = try #require(page.items.first)
        let task = AgendaTask(dto: dto)

        #expect(task.id == "01M2FVMQ0HZN3Y1JMCMYD4PS3M")
        #expect(task.statusRaw == "TODO")
        #expect(task.reasonRaw == "CALL")
        #expect(task.title == "Rappeler Mme Dupont")
        #expect(task.taskDescription == "Relance suite essayage")
        #expect(task.clientDisplayName == "Raphaël Van den Berg")
        #expect(task.store?.name == "My Custom Location")
        #expect(task.salesAssociate?.id == "01KTRSFERMNXK5FGSQW11M1478")
    }

    @Test("A null server reason decodes and maps to .other")
    func nullReasonMapsToOther() throws {
        let json = Data("""
        {
            "id": "task-no-reason",
            "status": "TODO",
            "reason": null,
            "title": "Sans motif",
            "startDate": "2026-09-20T10:00:00.000Z",
            "createdAt": "2026-09-14T11:43:05.743Z",
            "updatedAt": "2026-09-14T11:43:05.743Z"
        }
        """.utf8)

        let dto = try APIClient.makeDecoder().decode(TaskDTO.self, from: json)
        let task = AgendaTask(dto: dto)

        #expect(task.reasonRaw == Reason.other.rawValue)
        #expect(task.reason == .other)
    }
}
