//
//  FlowLayout.swift
//  FloorMobile
//

import SwiftUI

/// Views laid out one after the other, in reading order, going to a new line
/// when the width runs out: a filter's pills in "Sort & filter"
/// (`ClientFilterGroup`). `spacing` between two views of a line, `lineSpacing`
/// between two lines; on a line, the views are centred on its height.
///
/// A view is measured and placed at its ideal width, or at the width
/// available when it is wider: a pill longer than the row — a long segment
/// name, a large text size — takes a line of its own and wraps its text
/// rather than running past the edge.
///
/// A type of ours, on Apple's `Layout`: SwiftUI has no stack that wraps.
///
/// ```swift
/// FlowLayout(spacing: 6, lineSpacing: 0) {
///     ForEach(filter.values, id: \.ref) { value in
///         Pill(…) { Text(value.title) }
///     }
/// }
/// ```
nonisolated struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let arrangement = arrangement(of: subviews, in: proposal.width ?? .infinity)
        let width = arrangement.lines.map(\.width).max() ?? 0
        let height = arrangement.lines.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(arrangement.lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangement(of: subviews, in: bounds.width)
        var y = bounds.minY
        for line in arrangement.lines {
            var x = bounds.minX
            for index in line.range {
                let size = arrangement.sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    // MARK: - Lines

    /// Which views go on which line: each line takes the views that fit in
    /// `available`, `spacing` apart, and a view wider than the line takes one
    /// to itself. The lines' ranges, in order, covering every view.
    static func lines(widths: [CGFloat], available: CGFloat, spacing: CGFloat) -> [Range<Int>] {
        var lines: [Range<Int>] = []
        var start = 0
        var used: CGFloat = 0
        for (index, width) in widths.enumerated() {
            let needed = index == start ? width : used + spacing + width
            if index > start, needed > available {
                lines.append(start..<index)
                start = index
                used = width
            } else {
                used = needed
            }
        }
        if start < widths.count {
            lines.append(start..<widths.count)
        }
        return lines
    }

    // MARK: - Arrangement

    /// A line of views: which ones, and the room they take together.
    private struct Line {
        let range: Range<Int>
        let width: CGFloat
        let height: CGFloat
    }

    /// Each view's size — its ideal one, or the one it takes at `width` when
    /// it is wider — and the lines they make.
    private func arrangement(of subviews: Subviews, in width: CGFloat) -> (sizes: [CGSize], lines: [Line]) {
        let sizes = subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            return ideal.width > width
                ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
                : ideal
        }
        let ranges = Self.lines(widths: sizes.map(\.width), available: width, spacing: spacing)
        let lines = ranges.map { range in
            let line = sizes[range]
            return Line(
                range: range,
                width: line.reduce(0) { $0 + $1.width } + spacing * CGFloat(line.count - 1),
                height: line.map(\.height).max() ?? 0
            )
        }
        return (sizes, lines)
    }
}

// MARK: - Previews

#Preview {
    FlowLayout(spacing: 6, lineSpacing: 0) {
        ForEach(
            ["Last 30 days", "3 months", "6 months", "Last year", "Over a year ago", "None yet", "Since a date"],
            id: \.self
        ) { value in
            Pill(accessibilityLabel: value) {
                Text(verbatim: value).font(.subheadline.weight(.medium))
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ambientBackground()
}
