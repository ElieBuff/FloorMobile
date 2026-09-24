//
//  AIActionDTO.swift
//  FloorMobile
//

import Foundation

/// Wire format of an AI action, exactly as the API serves it.
///
/// A DTO is justified here (the rule is "no systematic DTOs"): the nested
/// people and product objects are flattened into the local model.
nonisolated struct AIActionDTO: Decodable {
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
    var client: ClientSummary?
    var salesAssociate: SalesAssociateSummary?
    /// The product a recommendation concerns, when it concerns one.
    var product: ProductDTO?

    nonisolated struct ProductDTO: Decodable {
        var name: String?
        var size: String?
        var price: Decimal?
        var currencyCode: String?
        var imageURL: URL?
    }
}

nonisolated extension AIAction {
    /// Maps the wire format into the local model, flattening the nested
    /// people and product.
    convenience init(dto: AIActionDTO) {
        self.init(
            id: dto.id,
            agentKey: dto.agentKey,
            type: dto.type,
            title: dto.title,
            reason: dto.reason,
            statusRaw: dto.status,
            createdAt: dto.createdAt,
            displayAt: dto.displayAt,
            eventDate: dto.eventDate,
            expiresAt: dto.expiresAt,
            rejectedAt: dto.rejectedAt,
            rejectReason: dto.rejectReason,
            confidence: dto.confidence,
            client: dto.client,
            salesAssociate: dto.salesAssociate,
            categoryLabel: dto.categoryLabel,
            productName: dto.product?.name,
            productSize: dto.product?.size,
            productPrice: dto.product?.price,
            productCurrencyCode: dto.product?.currencyCode,
            productImageURL: dto.product?.imageURL
        )
    }
}
