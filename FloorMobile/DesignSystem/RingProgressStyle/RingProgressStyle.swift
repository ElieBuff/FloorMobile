//
//  RingProgressStyle.swift
//  FloorMobile
//

import SwiftUI

/// A progress view drawn as a ring that fills clockwise from the top, its ends
/// rounded, on a faint track: the language download's, around the pebble
/// (canvas « Tolby - App », `C-Voix-Langue`).
///
/// A `ProgressViewStyle`, iOS's way to draw a `ProgressView` its own way: the
/// view keeps following what it is given — an iOS `Progress` included, with no
/// observation of ours. iOS's own `.circular` draws only a spinner on iPhone.
/// The ring's line runs along the edge of its frame, as the mockup's circle
/// does: a frame of 140 gives a circle of 140.
///
/// ```swift
/// ProgressView(progress)
///     .progressViewStyle(RingProgressStyle(lineWidth: 5, track: …, fill: …))
///     .frame(width: 140, height: 140)
/// ```
struct RingProgressStyle: ProgressViewStyle {
    let lineWidth: CGFloat
    /// The whole ring, under the part done.
    let track: Color
    /// The part done.
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: configuration.fractionCompleted ?? 0)
                .stroke(fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Previews

#Preview("Empty, 38 %, done") {
    HStack(spacing: 24) {
        ForEach([0, 0.38, 1], id: \.self) { fraction in
            ProgressView(value: fraction)
                .progressViewStyle(
                    RingProgressStyle(lineWidth: 5, track: Color(.OnSurface.borderSubtle), fill: Color(.Pebble.mid))
                )
                .frame(width: 80, height: 80)
        }
    }
    .ambientBackground()
}
