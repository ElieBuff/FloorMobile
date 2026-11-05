//
//  ClientProfile.swift
//  FloorMobile
//

import Foundation

/// A client's profile — the 360 view — as the profile page shows it: three
/// parts, each asked for on its own (`ClientService.details`, `summary`,
/// `timeline`) and each where it stands.
///
/// The parts arrive at their own pace — the AI summary can take 40 s, or
/// fail — so none waits on another: the page keeps one `ClientProfile` and
/// replaces a part as its call ends, and what reads the other parts is left
/// as it is. A plain value, never stored. The page adopts it with its display
/// of the three parts; it still loads the details alone.
nonisolated struct ClientProfile: Sendable {
    /// The client whose profile it is.
    let clientID: String
    /// Who they are.
    var details: Loadable<ClientDetails> = .loading
    /// Their AI summary.
    var summary: Loadable<ClientSummary> = .loading
    /// What is planned with them and what happened.
    var timeline: Loadable<ClientTimeline> = .loading
}
