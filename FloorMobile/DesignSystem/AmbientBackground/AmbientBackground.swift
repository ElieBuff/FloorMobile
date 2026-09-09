//
//  AmbientBackground.swift
//  FloorMobile
//

import SwiftUI

/// The app-wide two-layer ambient background: a static backdrop photo that
/// never moves, and a color wash + grain texture that travels with the
/// scrolling content above it.
///
/// Screens never place this view directly — they opt in through the
/// `.ambientBackground()` modifier (see `AmbientBackgroundModifier`), which
/// pins the backdrop, hides the scrollable's own background and feeds the
/// live scroll offset. This guarantees the backdrop stays static on every
/// screen, scrollable or not.
///
/// All geometry and values are transcribed from the Figma mockup (frame
/// 393×1381; wash group 728×852 at (-227, -90), coordinates below are
/// converted to screen space).
struct AmbientBackground: View {
    /// How far the content above has scrolled; the wash moves against it.
    var scrollOffset: CGFloat = 0

    /// Height of the design's reference canvas: in Figma the backdrop image
    /// is a "Fill" of the whole 393×1381 frame, and the phone screen only
    /// shows its top window. Framing the image against this height (instead
    /// of the screen) reproduces the exact crop and softness of the mockup.
    private static let referenceCanvasHeight: CGFloat = 1381

    /// Size of the Figma grain image (727×1492). The grain repeats itself
    /// vertically with this period, so scrolling can go on forever: noise is
    /// statistically uniform, which makes the seam between two copies
    /// invisible.
    private static let grainSize = CGSize(width: 727, height: 1492)

    var body: some View {
        // The wash and grain are much larger than the screen; as overlays
        // they decorate without inflating the layout — the backdrop alone
        // (which fills the screen) dictates the size.
        fixedBackdrop
            .overlay(alignment: .topLeading) {
                colorWash.offset(y: -scrollOffset)
            }
            .overlay(alignment: .topLeading) {
                grain
            }
            .allowsHitTesting(false)
    }

    // MARK: - Layer 1 — pinned backdrop

    /// Flat fill + backdrop photo, pinned to the screen.
    private var fixedBackdrop: some View {
        ZStack(alignment: .top) {
            Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5
            GeometryReader { geometry in
                Image("HomeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: Self.referenceCanvasHeight)
                    .clipped()
                    .opacity(0.4)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Layer 2 — moving wash

    /// The four soft blurred color blobs decorating the top of the content.
    /// They scroll away with it, by design. Frames, positions, opacities and
    /// blur radii come straight from the Figma layers.
    private var colorWash: some View {
        ZStack(alignment: .topLeading) {
            AmbientBlob( // #EAE9E5
                color: Color(red: 0.918, green: 0.914, blue: 0.898),
                size: CGSize(width: 587, height: 561),
                topLeft: CGPoint(x: -189, y: 318),
                blurRadius: 150,
                opacity: 0.7
            )
            AmbientBlob( // #B9B9B7
                color: Color(red: 0.725, green: 0.725, blue: 0.718),
                size: CGSize(width: 509, height: 393),
                topLeft: CGPoint(x: -59, y: -219),
                blurRadius: 150,
                opacity: 1
            )
            AmbientBlob( // #777777 (a freeform blob in Figma, close enough to an ellipse)
                color: Color(red: 0.467, green: 0.467, blue: 0.467),
                size: CGSize(width: 494, height: 717),
                topLeft: CGPoint(x: -260, y: -111),
                blurRadius: 140,
                opacity: 0.9
            )
            AmbientBlob( // #FEE9E7
                color: Color(red: 0.996, green: 0.914, blue: 0.906),
                size: CGSize(width: 401, height: 529),
                topLeft: CGPoint(x: 137, y: -17),
                blurRadius: 150,
                opacity: 0.9
            )
        }
    }

    /// The grain texture, moving with the content and repeating forever.
    ///
    /// The offset is wrapped modulo the image height, and two stacked copies
    /// always cover the screen — constant memory however far the user
    /// scrolls, and the elastic bounce (negative offsets) is covered by
    /// normalizing the wrap into [0, height).
    private var grain: some View {
        let height = Self.grainSize.height
        let wrapped = (scrollOffset.truncatingRemainder(dividingBy: height) + height)
            .truncatingRemainder(dividingBy: height)

        return VStack(spacing: 0) {
            grainTile
            grainTile
        }
        .opacity(0.15)
        .offset(x: -168, y: -111 - wrapped)
    }

    private var grainTile: some View {
        Image("HomeNoiseOverlay")
            .resizable()
            .frame(width: Self.grainSize.width, height: Self.grainSize.height)
    }
}

/// A soft, blurred ellipse of color — the building block of the ambient
/// color wash. Positioned by its Figma top-left corner in screen space.
private struct AmbientBlob: View {
    let color: Color
    let size: CGSize
    let topLeft: CGPoint
    let blurRadius: CGFloat
    let opacity: Double

    var body: some View {
        Ellipse()
            .fill(color)
            .frame(width: size.width, height: size.height)
            .opacity(opacity)
            .blur(radius: blurRadius)
            .offset(x: topLeft.x, y: topLeft.y)
    }
}

// MARK: - Previews

#Preview("Static screen") {
    VStack(spacing: 8) {
        Text("Static content")
            .font(.title2.bold())
        Text("Nothing here scrolls, so the wash never moves.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(24)
    .background(.white.opacity(0.85), in: .rect(cornerRadius: 24))
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ambientBackground()
}

#Preview("Long list — infinite grain") {
    List(0..<100) { index in
        Text("Row \(index)")
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .ambientBackground()
}

#Preview("Wash scrolled far away (offset 5000)") {
    AmbientBackground(scrollOffset: 5000)
}
