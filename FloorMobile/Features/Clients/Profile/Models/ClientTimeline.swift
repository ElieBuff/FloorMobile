//
//  ClientTimeline.swift
//  FloorMobile
//

import Foundation

/// One client's timeline (`client/{id}/timeline`): what is planned with them,
/// then what happened — their transactions, conversations, tasks and
/// appointments, every type at once. The third part of their profile
/// (`ClientProfile`). A plain value, asked for each time the profile opens,
/// never stored.
nonisolated struct ClientTimeline: Sendable, Equatable {
    /// Tasks still to do, late or not, and what is planned from now on, the
    /// earliest first.
    let upcoming: [ClientTimelineItem]
    /// What happened, the latest first.
    let past: [ClientTimelineItem]
}
