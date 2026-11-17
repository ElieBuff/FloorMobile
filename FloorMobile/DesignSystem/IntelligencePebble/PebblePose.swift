//
//  PebblePose.swift
//  FloorMobile
//

import SwiftUI

/// Where every moving part of the intelligence pebble is at one instant: its
/// outline, how it is turned, stretched and pushed aside, and its three
/// patches of light. `PebbleMotion` gives the pose of an instant;
/// `IntelligencePebble` draws it.
nonisolated struct PebblePose: Equatable {
    var outline: PebbleOutline = .rest
    /// The turn of the whole pebble.
    var rotation: Angle = .zero
    /// The stretch of the pebble along its own axes, before it is turned.
    var scale = CGSize(width: 1, height: 1)
    /// How far the pebble is pushed off its place, as fractions of its size.
    var offset: CGSize = .zero
    /// The white reflection, top leading.
    var light = Patch()
    /// The dark patch, bottom trailing.
    var dark = Patch()
    /// The pale glow, bottom trailing.
    var glow = Patch(opacity: 0.55)

    /// The pebble at rest: what `PebbleMotion.still` shows, and where every
    /// motion starts and ends its loop.
    static let rest = PebblePose()
}

extension PebblePose {
    /// One patch of light inside the pebble.
    nonisolated struct Patch: Equatable, Animatable {
        /// How far the patch is moved, as fractions of its own width and
        /// height.
        var offset: CGSize = .zero
        var scale: CGFloat = 1
        var opacity: Double = 1

        var animatableData: AnimatablePair<CGSize.AnimatableData, AnimatablePair<CGFloat, Double>> {
            get { AnimatablePair(offset.animatableData, AnimatablePair(scale, opacity)) }
            set {
                offset.animatableData = newValue.first
                scale = newValue.second.first
                opacity = newValue.second.second
            }
        }
    }
}
