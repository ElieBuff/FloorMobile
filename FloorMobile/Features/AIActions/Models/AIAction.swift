//
//  AIAction.swift
//  FloorMobile
//

import Foundation
import SwiftData

/// Status values the app knows how to interpret. The server set is open
/// (`REJECTED` is implied by `rejectedAt`/`rejectReason`), so an
/// unrecognized value simply yields a `nil` typed status — never a
/// decoding or mapping failure.
nonisolated enum AIActionStatus: String {
    case pending = "PENDING"
    case rejected = "REJECTED"
}

/// An action suggested to the sales associate by a Floor AI agent
/// (e.g. "wish this client a happy anniversary before their trip").
///
/// Local-first: rows are synchronized from the API in the background and
/// read by the views through `@Query`. `nonisolated` so a background
/// `ModelActor` can import instances off the main actor.
@Model
nonisolated final class AIAction {
    @Attribute(.unique) var id: String
    /// Every model carries its tenant: a store device can serve several
    /// brands, and rows from one tenant must never leak into another.
    var tenantId: String
    var agentKey: String
    /// Open server-side set (e.g. "ANNIVERSARY_TRAVEL_WISHES"): kept raw,
    /// the UI treats it as an opaque discriminator.
    var type: String
    var title: String
    var reason: String
    /// Raw server value; see `status` for the typed view.
    var statusRaw: String
    var createdAt: Date
    var displayAt: Date?
    var eventDate: Date?
    var expiresAt: Date?
    var rejectedAt: Date?
    var rejectReason: String?
    var confidence: Double?
    // Client and sales-associate names are denormalized: there is no local
    // Client model yet, and the card only needs a display name.
    var clientFirstName: String?
    var clientLastName: String?
    var salesAssociateFirstName: String?
    var salesAssociateLastName: String?

    init(
        id: String,
        tenantId: String,
        agentKey: String,
        type: String,
        title: String,
        reason: String,
        statusRaw: String,
        createdAt: Date,
        displayAt: Date? = nil,
        eventDate: Date? = nil,
        expiresAt: Date? = nil,
        rejectedAt: Date? = nil,
        rejectReason: String? = nil,
        confidence: Double? = nil,
        clientFirstName: String? = nil,
        clientLastName: String? = nil,
        salesAssociateFirstName: String? = nil,
        salesAssociateLastName: String? = nil
    ) {
        self.id = id
        self.tenantId = tenantId
        self.agentKey = agentKey
        self.type = type
        self.title = title
        self.reason = reason
        self.statusRaw = statusRaw
        self.createdAt = createdAt
        self.displayAt = displayAt
        self.eventDate = eventDate
        self.expiresAt = expiresAt
        self.rejectedAt = rejectedAt
        self.rejectReason = rejectReason
        self.confidence = confidence
        self.clientFirstName = clientFirstName
        self.clientLastName = clientLastName
        self.salesAssociateFirstName = salesAssociateFirstName
        self.salesAssociateLastName = salesAssociateLastName
    }

    /// Typed status; `nil` when the server sends a value this app version
    /// does not know.
    var status: AIActionStatus? {
        AIActionStatus(rawValue: statusRaw)
    }

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        let name = [clientFirstName, clientLastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    /// The date is injected — never `Date()` inside the logic — so the rule
    /// is testable at any point in time.
    func isExpired(at date: Date) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= date
    }

    /// A card is shown when its display window has opened, it has not
    /// expired, and the action is still pending.
    func isDisplayable(at date: Date) -> Bool {
        guard status == .pending, !isExpired(at: date) else { return false }
        guard let displayAt else { return true }
        return displayAt <= date
    }
}
