//
//  ClientSummary.swift
//  FloorMobile
//

import Foundation

/// One client's AI summary (`client/{id}/summary`): who they are and where
/// the relationship stands, read at three lengths, then the one thing to do.
/// The second part of their profile (`ClientProfile`).
///
/// Written by the server's AI from the client's whole dossier, in English;
/// a plain value, asked for each time the profile opens, never stored.
nonisolated struct ClientSummary: Sendable, Equatable {
    /// One line: who they are and the opportunity.
    let title: String
    /// Two sentences, read in about 5 s.
    let brief: String
    /// Four to eight short sentences, developing the brief.
    let prose: String
    /// The one action recommended to the associate.
    let nextStep: String
    /// The relationship's tone; `nil` for a value this build does not know.
    let mood: Mood?

    /// The tone of a client's relationship, as the AI reads it.
    nonisolated enum Mood: String, Sendable {
        case positive = "POSITIVE"
        case neutral = "NEUTRAL"
        case negative = "NEGATIVE"
    }
}
