//
//  AIActionDTO.swift
//  FloorMobile
//

import Foundation

/// Wire format of an AI action, exactly as the API serves it.
///
/// A DTO is justified here (the rule is "no systematic DTOs"): the nested
/// people objects are flattened into the local model.
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
    var client: PersonDTO?
    var salesAssociate: PersonDTO?
}

nonisolated extension AIAction {
    /// Maps the wire format into the local model, flattening the nested people.
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
            clientFirstName: dto.client?.firstName,
            clientLastName: dto.client?.lastName,
            salesAssociateFirstName: dto.salesAssociate?.firstName,
            salesAssociateLastName: dto.salesAssociate?.lastName
        )
    }
}
