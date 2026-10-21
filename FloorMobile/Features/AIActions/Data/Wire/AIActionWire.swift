//
//  AIActionWire.swift
//  FloorMobile
//

import Foundation

/// Wire format of an AI action. Read-only: the app never writes one back, so
/// there is no `Request`.
nonisolated enum AIActionWire {
    /// An AI action exactly as the API serves it.
    ///
    /// A wire type is justified here (the rule is "no systematic DTOs"): the
    /// nested people and product objects are flattened into the local model.
    struct Response: Decodable {
        var id: String
        var agentKey: String
        var type: String
        var title: String
        var reason: String
        var status: String
        var createdAt: Date
        var displayAt: Date?
        var eventDate: Date?
        var expiresAt: Date?
        var rejectedAt: Date?
        var rejectReason: String?
        var confidence: Double?
        /// The uppercase tag shown on the Home card; not sent by every agent.
        var categoryLabel: String?
        var client: ClientSummaryWire?
        var salesAssociate: SalesAssociateWire?
        /// The product a recommendation concerns, when it concerns one.
        var product: Product?

        struct Product: Decodable {
            var name: String?
            var size: String?
            var price: Decimal?
            var currencyCode: String?
            var imageURL: URL?
        }
    }
}

nonisolated extension AIAction {
    /// Maps the wire format into the local model, flattening the nested
    /// people and product.
    convenience init(wire: AIActionWire.Response) {
        self.init(
            id: wire.id,
            agentKey: wire.agentKey,
            type: wire.type,
            title: wire.title,
            reason: wire.reason,
            statusRaw: wire.status,
            createdAt: wire.createdAt,
            displayAt: wire.displayAt,
            eventDate: wire.eventDate,
            expiresAt: wire.expiresAt,
            rejectedAt: wire.rejectedAt,
            rejectReason: wire.rejectReason,
            confidence: wire.confidence,
            client: wire.client.map(ClientSummary.init(wire:)),
            salesAssociate: wire.salesAssociate.map(SalesAssociateSummary.init(wire:)),
            categoryLabel: wire.categoryLabel,
            productName: wire.product?.name,
            productSize: wire.product?.size,
            productPrice: wire.product?.price,
            productCurrencyCode: wire.product?.currencyCode,
            productImageURL: wire.product?.imageURL
        )
    }
}
