//
//  PebbleOutline.swift
//  FloorMobile
//

import SwiftUI

/// The outline of the intelligence pebble: a closed curve of four elliptical
/// corners, each with its own horizontal and vertical radius — no native shape
/// has corners of two radii, all different.
///
/// The radii are fractions of the rectangle's width (horizontal) and height
/// (vertical), as the mockup writes them (`58% 42% 55% 45% / 48% 60% 40% 52%`).
/// On every side the two radii that meet add up to 1, so the curve has no
/// straight part; blending two such outlines keeps that sum, which is why the
/// outline can be animated value by value.
nonisolated struct PebbleOutline: Shape, Equatable {
    /// Horizontal radii, as fractions of the width.
    var topLeading: CGFloat
    var topTrailing: CGFloat
    var bottomTrailing: CGFloat
    var bottomLeading: CGFloat
    /// Vertical radii, as fractions of the height, in the same order.
    var topLeadingRise: CGFloat
    var topTrailingRise: CGFloat
    var bottomTrailingRise: CGFloat
    var bottomLeadingRise: CGFloat

    /// The outline from the mockup's eight percentages, in its order: the four
    /// horizontal radii, then the four vertical ones, each from the top
    /// leading corner clockwise.
    init(_ horizontal: [CGFloat], _ vertical: [CGFloat]) {
        precondition(horizontal.count == 4 && vertical.count == 4, "A pebble outline has four corners")
        topLeading = horizontal[0] / 100
        topTrailing = horizontal[1] / 100
        bottomTrailing = horizontal[2] / 100
        bottomLeading = horizontal[3] / 100
        topLeadingRise = vertical[0] / 100
        topTrailingRise = vertical[1] / 100
        bottomTrailingRise = vertical[2] / 100
        bottomLeadingRise = vertical[3] / 100
    }

    /// The pebble at rest.
    static let rest = PebbleOutline([58, 42, 55, 45], [48, 60, 40, 52])

    // MARK: - Shape

    /// How far a cubic curve's control points sit along a quarter of an
    /// ellipse's radii.
    private static let quarterArc: CGFloat = 0.5523

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let reach = Self.quarterArc
        let topLeft = CGSize(width: topLeading * width, height: topLeadingRise * height)
        let topRight = CGSize(width: topTrailing * width, height: topTrailingRise * height)
        let bottomRight = CGSize(width: bottomTrailing * width, height: bottomTrailingRise * height)
        let bottomLeft = CGSize(width: bottomLeading * width, height: bottomLeadingRise * height)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight.width, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topRight.height),
            control1: CGPoint(x: rect.maxX - topRight.width * (1 - reach), y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + topRight.height * (1 - reach))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height))
        path.addCurve(
            to: CGPoint(x: rect.maxX - bottomRight.width, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight.height * (1 - reach)),
            control2: CGPoint(x: rect.maxX - bottomRight.width * (1 - reach), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft.width, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height),
            control1: CGPoint(x: rect.minX + bottomLeft.width * (1 - reach), y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft.height * (1 - reach))
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft.height))
        path.addCurve(
            to: CGPoint(x: rect.minX + topLeft.width, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + topLeft.height * (1 - reach)),
            control2: CGPoint(x: rect.minX + topLeft.width * (1 - reach), y: rect.minY)
        )
        path.closeSubpath()
        return path
    }

    // MARK: - Animatable

    private typealias Pair = AnimatablePair<CGFloat, CGFloat>
    private typealias Quad = AnimatablePair<Pair, Pair>

    /// The eight radii, so a keyframe track can blend two outlines.
    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>,
                                       AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(
                Quad(Pair(topLeading, topTrailing), Pair(bottomTrailing, bottomLeading)),
                Quad(Pair(topLeadingRise, topTrailingRise), Pair(bottomTrailingRise, bottomLeadingRise))
            )
        }
        set {
            topLeading = newValue.first.first.first
            topTrailing = newValue.first.first.second
            bottomTrailing = newValue.first.second.first
            bottomLeading = newValue.first.second.second
            topLeadingRise = newValue.second.first.first
            topTrailingRise = newValue.second.first.second
            bottomTrailingRise = newValue.second.second.first
            bottomLeadingRise = newValue.second.second.second
        }
    }
}
