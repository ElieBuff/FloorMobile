//
//  ProductThumbnail.swift
//  FloorMobile
//

import SwiftUI

/// A square product image with rounded corners, loaded asynchronously. While
/// loading — or when there is no URL — it shows a neutral placeholder surface,
/// so the layout never jumps between the loading and loaded states.
struct ProductThumbnail: View {
    let url: URL?
    var size: CGFloat = 76
    var cornerRadius: CGFloat = AppRadius.medium
    /// What VoiceOver announces. `nil` — the default — hides the image, which is
    /// right wherever the text beside it already names the product; a thumbnail
    /// standing on its own passes a label so it is not skipped.
    var label: String? = nil

    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Color(.OnCanvas.surfaceSubtle)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }
}

// MARK: - Previews

#Preview {
    HStack(spacing: 16) {
        ProductThumbnail(url: URL(string: "https://picsum.photos/200"))
        ProductThumbnail(url: nil)
    }
    .padding(40)
    .background(Color.black)
}
