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
nonisolated final class AIAction: Syncable {
    @Attribute(.unique) var id: String
    /// Per-sync generation marker (mark-and-sweep); not from the API.
    var syncToken: String = ""

    /// Rows the latest refresh did not return (see `Syncable`).
    static func stale(token: String) -> Predicate<AIAction> {
        #Predicate { $0.syncToken != token }
    }
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
    /// The client and sales associate this action concerns, as embedded
    /// display snapshots.
    var client: PersonSummary?
    var salesAssociate: PersonSummary?
    /// The uppercase tag shown on the Home card ("BACK IN STOCK", "AWAITING
    /// YOUR REPLY"). Falls back to `type` in the view when the server
    /// hasn't started sending it.
    var categoryLabel: String?
    // The product a recommendation concerns, when it concerns one (e.g. a
    // "back in stock" tip). All optional: most agents don't attach a
    // product, and the API doesn't send these fields yet.
    var productName: String?
    var productSize: String?
    var productPrice: Decimal?
    var productCurrencyCode: String?
    var productImageURL: URL?

    init(
        id: String,
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
        client: PersonSummary? = nil,
        salesAssociate: PersonSummary? = nil,
        categoryLabel: String? = nil,
        productName: String? = nil,
        productSize: String? = nil,
        productPrice: Decimal? = nil,
        productCurrencyCode: String? = nil,
        productImageURL: URL? = nil
    ) {
        self.id = id
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
        self.client = client
        self.salesAssociate = salesAssociate
        self.categoryLabel = categoryLabel
        self.productName = productName
        self.productSize = productSize
        self.productPrice = productPrice
        self.productCurrencyCode = productCurrencyCode
        self.productImageURL = productImageURL
    }

    /// Typed status; `nil` when the server sends a value this app version
    /// does not know.
    var status: AIActionStatus? {
        AIActionStatus(rawValue: statusRaw)
    }

    /// "Elie Buff", "Elie", "Buff", or `nil` when the API sent no name.
    var clientDisplayName: String? {
        client?.displayName
    }

    /// "Salomé Kaliny · Gold", or just the name when there is no tier.
    var clientMetaLine: String? {
        guard let clientDisplayName else { return nil }
        guard let tier = client?.tier, !tier.isEmpty else { return clientDisplayName }
        return "\(clientDisplayName) · \(tier)"
    }

    /// "2 400 €" in the product's own currency, `nil` until both the price
    /// and its currency are known.
    var productPriceFormatted: String? {
        guard let productPrice, let productCurrencyCode else { return nil }
        return productPrice.formatted(.currency(code: productCurrencyCode))
    }

    /// "Beaded cream dress · 38 · 2 400 €", joining whichever product
    /// details are present and omitting the rest — `nil` when none are.
    var productMetaLine: String? {
        let parts = [productName, productSize, productPriceFormatted].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
