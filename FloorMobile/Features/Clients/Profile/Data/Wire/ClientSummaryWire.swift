//
//  ClientSummaryWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of `ClientSummary`: what `client/{id}/summary` serves — the
/// five fields of one client's AI summary, always in English. Read-only.
nonisolated enum ClientSummaryWire {
    struct Response: Decodable, Sendable {
        var title: String
        var brief: String
        var prose: String
        var nextStep: String
        /// `POSITIVE`, `NEUTRAL` or `NEGATIVE`.
        var mood: String
    }
}

nonisolated extension ClientSummary {
    /// Maps the wire format into the summary; a mood this build does not
    /// know becomes `nil`.
    init(wire: ClientSummaryWire.Response) {
        self.init(
            title: wire.title,
            brief: wire.brief,
            prose: wire.prose,
            nextStep: wire.nextStep,
            mood: Mood(rawValue: wire.mood)
        )
    }
}
