//
//  ClientDetails.swift
//  FloorMobile
//

import Foundation

/// Who a client is, as the server holds it (`client/{id}`): the first part of
/// their profile (`ClientProfile`), asked for each time the associate opens
/// it. Bounded: their purchases and messages are the timeline's
/// (`ClientTimeline`).
///
/// A plain value, never stored: any client of the brand can be opened, while
/// the device keeps only its store's. Their important dates, household and
/// preferences come once the server fills them.
nonisolated struct ClientDetails: Identifiable, Sendable, Equatable {
    /// The client's card: who they are, where they belong, how to reach them.
    let client: ClientItem
    /// The server's own value (`MR`, `MRS`…), an open set, as received.
    let salutation: String?
    /// Their main address, `nil` when the server has none.
    let address: Address?
    /// An ISO 639-1 code ("fr", "en", "zh").
    let preferredLanguage: String?
    /// What they agreed to be reached by.
    let optIns: OptIns

    var id: String { client.id }

    /// A client's address, each line as the source wrote it.
    nonisolated struct Address: Sendable, Equatable {
        /// Both street lines, joined by a comma.
        let street: String?
        let postalCode: String?
        let city: String?
        let state: String?
        /// A code ("FR") or a name, as the source wrote it.
        let country: String?
    }

    /// What a client agreed to be reached by.
    nonisolated struct OptIns: Sendable, Equatable {
        let email: Bool
        /// Instant messaging: WhatsApp, SMS.
        let directMessage: Bool
        /// A call on their phone.
        let call: Bool
        let wechat: Bool
        let line: Bool
    }
}
