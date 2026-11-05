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
/// fail — so none waits on another: the page (`ClientProfileView`) keeps one
/// `ClientProfile` and replaces a part as its call ends, and what reads the
/// other parts is left as it is. A plain value, never stored.
nonisolated struct ClientProfile: Sendable {
    /// The client whose profile it is.
    let clientID: String
    /// Who they are.
    var details: Loadable<ClientDetails> = .loading
    /// Their AI summary.
    var summary: Loadable<ClientSummary> = .loading
    /// What is planned with them and what happened.
    var timeline: Loadable<ClientTimeline> = .loading

    /// Why a part could not be loaded — the details', else the summary's,
    /// else the timeline's — or `nil` when none failed. One error for the
    /// page's one notice: parts that fail together, offline, fail alike.
    var firstError: (any Error)? {
        details.error ?? summary.error ?? timeline.error
    }

    /// Asks again for every part that failed — each back to `.loading`, which
    /// the page's loads wait on; a part on its way or loaded is left as it is.
    mutating func retryFailed() {
        if details.error != nil { details = .loading }
        if summary.error != nil { summary = .loading }
        if timeline.error != nil { timeline = .loading }
    }
}
