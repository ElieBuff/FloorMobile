//
//  AmbientBackground.swift
//  FloorMobile
//

import SwiftUI

/// The app-wide two-layer ambient background:
///
/// - **Pinned layer** — the designer's full composition exported from Figma
///   (`AmbientBackdrop`: flat fill + backdrop photo + color halos). It never
///   moves; the screen shows its top window, identical at any scroll depth.
/// - **Moving layer** — the grain texture, travelling with the scrolling
///   content and repeating forever.
///
/// Screens never place this view directly — they opt in through the
/// `.ambientBackground()` modifier (see `AmbientBackgroundModifier`), which
/// pins the backdrop, hides the scrollable's own background and feeds the
/// live scroll offset.
///
/// Transcribing the composition natively (blurred shapes, blend modes,
/// image-fill crops) proved unfaithful to the mockup, so the exported image
/// is the source of truth. Re-export the Figma frame (grain hidden, PNG 2x)
/// if the design changes.
struct AmbientBackground: View {
    /// How far the content above has scrolled; the grain moves against it.
    var scrollOffset: CGFloat = 0

    /// Point size of the design's reference canvas. The Figma frame is
    /// 393×1381 but positions the composition 288 pt lower than the Home
    /// screen mockup shows it; since the backdrop is pinned top-aligned, that
    /// top band would never be visible, so the asset is the export with its
    /// top 288 pt cropped off (alignment measured by cross-correlating the
    /// export against the mockup).
    private static let referenceCanvasSize = CGSize(width: 393, height: 1093)

    /// Size of the Figma grain image (727×1492). The grain repeats itself
    /// vertically with this period, so scrolling can go on forever: noise is
    /// statistically uniform, which makes the seam between two copies
    /// invisible.
    private static let grainSize = CGSize(width: 727, height: 1492)

    var body: some View {
        // The grain is much larger than the screen; as an overlay it
        // decorates without inflating the layout — the backdrop alone
        // (which fills the screen) dictates the size.
        fixedBackdrop
            .overlay(alignment: .topLeading) {
                grain
            }
            .allowsHitTesting(false)
    }

    /// The designer's composition, pinned to the screen and scaled against
    /// the screen width so wider phones keep the framing. The flat color
    /// backs up any area the image would not cover.
    private var fixedBackdrop: some View {
        ZStack(alignment: .top) {
            Color(red: 0.961, green: 0.961, blue: 0.961) // #F5F5F5
            GeometryReader { geometry in
                let scale = geometry.size.width / Self.referenceCanvasSize.width
                Image("AmbientBackdrop")
                    .resizable()
                    .frame(
                        width: geometry.size.width,
                        height: Self.referenceCanvasSize.height * scale
                    )
            }
        }
        .ignoresSafeArea()
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
        // 0.18 rather than Figma's 0.15: measured against the mockup export,
        // plain alpha compositing renders the grain ~20% weaker over the
        // photo/halo area than Figma does, and this compensates.
        .opacity(0.18)
        .offset(x: -168, y: -111 - wrapped)
    }

    private var grainTile: some View {
        Image("AmbientGrain")
            .resizable()
            .frame(width: Self.grainSize.width, height: Self.grainSize.height)
    }
}

// MARK: - Previews

#Preview("Static screen") {
    VStack(spacing: 8) {
        Text("Static content")
            .font(.title2.bold())
        Text("Nothing here scrolls, so only the grain would move.")
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

#Preview("Scrolled far away (offset 5000)") {
    AmbientBackground(scrollOffset: 5000)
}

#Preview("Background alone — mockup comparison") {
    AmbientBackground()
}
