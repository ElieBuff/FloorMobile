//
//  ClientSignature.swift
//  FloorMobile
//

import Foundation

/// The client's signature under their contact preferences, as the signature
/// sheet (`ClientSignatureSheet`) takes it: the drawing as a PNG, and when
/// they signed.
///
/// Worth only the consents on screen when it was given: the editor drops it
/// as soon as a consent changes, so a save never sends one the client did not
/// sign. A plain value, kept by the editor until the save goes through.
nonisolated struct ClientSignature: Sendable, Equatable {
    /// The drawing, rendered on white (`PKDrawing.signaturePNG(scale:)`).
    let png: Data
    let signedAt: Date
}
