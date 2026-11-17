//
//  AmbientBackground.swift
//  FloorMobile
//

import SwiftUI

/// The app-wide two-layer ambient background:
///
/// - **Pinned layer** — a flat ivory (`Base.canvas`). It never moves, so the
///   content always scrolls over one colour and its text keeps one colour too.
/// - **Moving layer** — four blurred shapes that breathe (`AmbientEllipse`),
///   hung at the top of the page and travelling with the scrolling content.
///   Once the content has scrolled past them, the page is plain ivory.
///
/// Screens never place this view directly — they opt in through the
/// `.ambientBackground()` modifier (see `AmbientBackgroundModifier`), which
/// hides the scrollable's own background and feeds the distance scrolled.
///
/// The shapes are drawn natively, from the mockup's own numbers: plain blurred
/// ellipses over a flat fill, with no photo, blend mode or image crop to
/// reproduce. The blur radii are the mockup's, used as they are.
///
/// Each shape is blurred once, into a picture the whole app shares, and the
/// breath only moves, swells and fades that picture. Blurring the live shapes
/// instead looks the same and was measured on an iPhone 18 Pro Max: 22
/// offscreen passes and about 6 ms of GPU for every frame, thirty times a
/// second for as long as a screen showed.
///
/// The breath is read off absolute time through `TimelineView` rather than
/// played by an animation: each screen and each sheet draws its own background,
/// and all of them must show the same instant of the same breath (see
/// `AmbientEllipse`). It also gives one pause switch — Reduce Motion, where the
/// shapes hold their still pose, and an app that is not active. A background
/// whose shapes have scrolled out of sight draws none of them and runs no
/// clock: a long list should not redraw thirty times a second for nothing.
struct AmbientBackground: View {
    /// How far past a shape's edge its picture goes, in blur radii. At three
    /// the halo has faded to nothing, so the picture's border never shows.
    private static let haloReach: CGFloat = 3

    /// Pixels per reference point in a shape's picture. A blur this wide holds
    /// no detail a quarter of the resolution would lose, and the four pictures
    /// weigh 2 MB instead of 30.
    private static let pictureScale: CGFloat = 0.25

    /// Each shape with its blur, in the order of `AmbientEllipse.all`, drawn
    /// the first time a background appears.
    private static let pictures = AmbientEllipse.all.map { picture(of: $0) }

    /// How far the content above has scrolled from rest, in screen points; the
    /// shapes move up by as much.
    var scrollOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            Color(.Base.canvas)
                // As an overlay the shapes decorate without inflating the
                // layout: the flat fill alone, which fills the screen,
                // dictates the size.
                .overlay(alignment: .topLeading) {
                    if scrollOffset < AmbientEllipse.reach(forWidth: width) {
                        shapes(scale: width / AmbientEllipse.referenceWidth)
                            .offset(y: -scrollOffset)
                    }
                }
        }
        // The shapes are wider than the screen. Unclipped, they would paint
        // over the neighbouring screen while a push slides it in.
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Stops the clock when motion is unwelcome (Reduce Motion) or unseen (the
    /// app is not active). Resuming does not restart the breath: the shapes
    /// pick it up wherever it would have been.
    private var isPaused: Bool {
        reduceMotion || scenePhase != .active
    }

    /// The four shapes, back to front, breathing.
    ///
    /// - Parameter scale: screen points per reference point, so wider phones
    ///   keep the mockup's framing.
    private func shapes(scale: CGFloat) -> some View {
        // 30 fps is well above what a 14-second breath needs, and a quarter of
        // the work of matching a 120 Hz display for no visible gain.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { context in
            ZStack(alignment: .topLeading) {
                ForEach(AmbientEllipse.all.indices, id: \.self) { index in
                    if let picture = Self.pictures[index] {
                        let ellipse = AmbientEllipse.all[index]
                        shape(
                            ellipse,
                            picture: picture,
                            pose: reduceMotion ? ellipse.still : ellipse.pose(at: context.date),
                            scale: scale
                        )
                    }
                }
            }
        }
    }

    /// One shape in a given pose. The picture already holds the blur, so a
    /// shape that swells carries its halo with it, as in the mockup.
    private func shape(
        _ ellipse: AmbientEllipse,
        picture: Image,
        pose: AmbientEllipse.Pose,
        scale: CGFloat
    ) -> some View {
        let halo = ellipse.blurRadius * Self.haloReach

        return picture
            .resizable()
            .frame(
                width: (ellipse.frame.width + 2 * halo) * scale,
                height: (ellipse.frame.height + 2 * halo) * scale
            )
            .scaleEffect(pose.scale)
            .opacity(pose.opacity)
            .offset(
                x: (ellipse.frame.minX - halo + pose.offset.width) * scale,
                y: (ellipse.frame.minY - halo + pose.offset.height) * scale
            )
    }

    /// A shape and its blur as a picture, in reference points, with room all
    /// around for the halo. `nil` if SwiftUI cannot draw it: that shape is then
    /// missing from the background, which stays a plain ivory there.
    private static func picture(of ellipse: AmbientEllipse) -> Image? {
        let renderer = ImageRenderer(
            content: Ellipse()
                .fill(Color(ellipse.color))
                .frame(width: ellipse.frame.width, height: ellipse.frame.height)
                .blur(radius: ellipse.blurRadius)
                .padding(ellipse.blurRadius * haloReach)
        )
        renderer.scale = pictureScale
        return renderer.cgImage.map { Image(decorative: $0, scale: pictureScale) }
    }
}

// MARK: - Previews

#Preview("Static screen") {
    VStack(spacing: 8) {
        Text("Static content")
            .font(.title2.bold())
        Text("Nothing here scrolls, so the shapes stay where they hang.")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(24)
    .background(.white.opacity(0.85), in: .rect(cornerRadius: AppRadius.large))
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ambientBackground()
}

#Preview("Long list — the shapes scroll away") {
    List(0..<100) { index in
        Text("Row \(index)")
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .ambientBackground()
}

#Preview("Scrolled part of the way (offset 300)") {
    AmbientBackground(scrollOffset: 300)
}

#Preview("Background alone — mockup comparison") {
    AmbientBackground()
}
