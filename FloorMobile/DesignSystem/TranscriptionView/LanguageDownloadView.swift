//
//  LanguageDownloadView.swift
//  FloorMobile
//

import SwiftUI

/// The transcription element while iOS downloads the language picked
/// (`LanguageDownload`), as the mockup draws it (canvas « Tolby - App »,
/// `C-Voix-Langue`): the pebble, faint and still, inside a ring that fills as
/// the model arrives (`RingProgressStyle`); "Downloading French" and iOS's
/// three dots lighting up in turn; how far it is, "38%". `TranscriptionView`
/// shows it in place of the listening, and "Cancel download" in place of the
/// screen's action.
///
/// No sizes: iOS does not give them. Its `Progress` calls itself a file
/// download (`kind == .file`, which means bytes) but counts one unit in all,
/// and only its fraction moves — no throughput, no description (measured on
/// 16/11).
///
/// The ring follows iOS's `Progress` by itself (`ProgressView`); the line
/// under it is read again twice a second, the `Progress` saying nothing to
/// SwiftUI. For VoiceOver, one element: "Downloading French (France)", and how
/// far it is.
struct LanguageDownloadView: View {
    /// The language downloading.
    let locale: Locale
    /// iOS's progress of the download.
    let progress: Progress

    /// The pebble, its box and the ring around it: the mockup's.
    private static let pebbleSize: CGFloat = 80
    private static let pebbleOpacity = 0.45
    private static let boxSize: CGFloat = 160
    private static let ringSize: CGFloat = 140
    private static let ringLineWidth: CGFloat = 5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            VStack(spacing: 0) {
                ZStack {
                    ProgressView(progress)
                        .progressViewStyle(
                            RingProgressStyle(
                                lineWidth: Self.ringLineWidth,
                                track: Color(.OnSurface.borderSubtle),
                                fill: Color(.Pebble.mid)
                            )
                        )
                        .frame(width: Self.ringSize, height: Self.ringSize)
                    IntelligencePebble(size: Self.pebbleSize, motion: .still)
                        .opacity(Self.pebbleOpacity)
                }
                .frame(width: Self.boxSize, height: Self.boxSize)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(localized: "Downloading \(locale.languageName())"))
                    Image(systemName: "ellipsis")
                        .symbolEffect(.variableColor.iterative)
                }
                .font(.callout.weight(.medium))
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .padding(.top, 4)

                Text(Self.percentage(progress.fractionCompleted))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color(.OnSurface.textSecondary))
                    .padding(.top, 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Downloading \(locale.displayName())"))
            .accessibilityValue(Self.percentage(progress.fractionCompleted))
        }
    }

    // MARK: - Percentage

    /// How far a download is, "38%", rounded to the unit, in `locale`'s
    /// writing: the line under the ring and VoiceOver's value.
    static func percentage(_ fraction: Double, locale: Locale = .current) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

// MARK: - Previews

#Preview("38 %") {
    let progress = Progress(totalUnitCount: 100)
    progress.completedUnitCount = 38

    return LanguageDownloadView(locale: Locale(identifier: "fr_FR"), progress: progress)
        .ambientBackground()
}
