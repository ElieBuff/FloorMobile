//
//  EmptySectionActionTests.swift
//  FloorMobileTests
//

import Testing
@testable import FloorMobile

@Suite("EmptySectionCard action")
struct EmptySectionActionTests {
    @Test("An action defaults to having no leading symbol")
    func defaultsToNoSystemImage() {
        let action = EmptySectionAction(label: "View agenda") {}
        #expect(action.systemImage == nil)
        #expect(action.label == "View agenda")
    }

    @Test("The handler runs exactly once per invocation")
    func handlerRunsOncePerInvocation() async {
        await confirmation("handler invoked", expectedCount: 1) { invoked in
            let action = EmptySectionAction(label: "Create task", systemImage: "plus") {
                invoked()
            }
            action.handler()
        }
    }
}
