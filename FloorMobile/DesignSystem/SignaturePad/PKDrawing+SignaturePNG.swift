//
//  PKDrawing+SignaturePNG.swift
//  FloorMobile
//

import PencilKit
import UIKit

extension PKDrawing {
    /// The drawing as a PNG on white, cut to its strokes — the image a
    /// signature is sent as; `nil` with nothing drawn.
    ///
    /// Rendered in light mode whatever the device's: PencilKit draws black
    /// ink white in dark mode, and the server expects the same signature
    /// whichever mode it was taken in. On white, since PencilKit's own image
    /// is transparent.
    func signaturePNG(scale: CGFloat = 2) -> Data? {
        guard !strokes.isEmpty else { return nil }
        let bounds = self.bounds.insetBy(dx: -8, dy: -8)
        var ink = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            ink = image(from: bounds, scale: scale)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: bounds.size, format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds.size))
            ink.draw(at: .zero)
        }
    }
}
