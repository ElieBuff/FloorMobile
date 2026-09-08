//
//  AppErrorTests.swift
//  FloorMobileTests
//

import Foundation
import Testing
@testable import FloorMobile

@Suite("AppError user-facing messages")
struct AppErrorTests {

    @Test("Every error case produces a non-empty user message", arguments: [
        AppError.network(underlying: nil),
        AppError.server(statusCode: 500),
        AppError.decoding(underlying: URLError(.cannotParseResponse)),
        AppError.authentication(.userCancelled),
        AppError.authentication(.invalidCallback),
        AppError.authentication(.sessionExpired),
        AppError.authentication(.refreshFailed),
        AppError.storage(underlying: nil),
        AppError.unexpected(description: "test"),
    ])
    func hasUserMessage(error: AppError) throws {
        let message = try #require(error.errorDescription)
        #expect(!message.isEmpty)
    }

    @Test("Auth failures produce distinct messages")
    func distinctAuthMessages() throws {
        let failures: [AppError.AuthFailure] = [
            .userCancelled, .invalidCallback, .sessionExpired, .refreshFailed,
        ]
        let messages = try failures.map {
            try #require(AppError.authentication($0).errorDescription)
        }
        #expect(Set(messages).count == failures.count)
    }

    @Test("Server error message includes the status code")
    func serverMessageIncludesCode() throws {
        let message = try #require(AppError.server(statusCode: 503).errorDescription)
        #expect(message.contains("503"))
    }
}
