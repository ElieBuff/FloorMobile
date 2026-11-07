//
//  SignaturePNGTests.swift
//  FloorMobileTests
//

import PencilKit
import Testing
import UIKit
@testable import FloorMobile

/// The image a signature is sent as: nothing for an empty pad, an opaque PNG
/// on white otherwise.
@MainActor
@Suite("Signature PNG")
struct SignaturePNGTests {

    /// One stroke across the pad, as a finger would draw it.
    private static func signed() -> PKDrawing {
        let points = (0..<20).map { step in
            PKStrokePoint(
                location: CGPoint(x: 20 + Double(step) * 10, y: 60 + Double(step % 4) * 6),
                timeOffset: Double(step) * 0.02, size: CGSize(width: 3, height: 3),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: points, creationDate: .now)
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: path)])
    }

    @Test("An empty pad gives no image")
    func emptyGivesNothing() {
        #expect(PKDrawing().signaturePNG() == nil)
    }

    @Test("A signature gives a PNG, opaque, at the scale asked")
    func signatureGivesAPNG() throws {
        let drawing = Self.signed()

        let png = try #require(drawing.signaturePNG(scale: 2))

        // The PNG signature, then an image the size of the strokes, doubled.
        #expect(Array(png.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])
        let image = try #require(UIImage(data: png)?.cgImage)
        let bounds = drawing.bounds.insetBy(dx: -8, dy: -8)
        #expect(abs(Double(image.width) - bounds.width * 2) <= 1)
        // Opaque: the white ground is part of the image.
        #expect([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
    }
}
