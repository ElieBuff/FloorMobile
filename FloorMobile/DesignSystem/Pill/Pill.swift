//
//  Pill.swift
//  FloorMobile
//

import SwiftUI

/// A capsule to pick or to take off: a value among others — a segment, a
/// status, in "Sort & filter" —, or a filter applied, with its cross. Drawn as
/// the mockups draw it (canvas « Tolby - App », `C-Filtres`, `C-ListeFiltree`):
/// a capsule at least 36 pt high, 14 pt each side — 10 on the right with the
/// cross —, white at 70 %, the ink once chosen; in a 44 pt band, Apple's tap
/// target, which the layout keeps, as the mockup's button does.
///
/// What it shows is the page's (`content`): the text and its size, a coloured
/// dot, Tolby's violet — a content of several views comes in its own stack,
/// with its own spacing (the mockup's 7 pt between a dot and its word); the
/// pill puts 6 pt between it and the cross. The pill sets the foreground —
/// the paper once chosen, the ink otherwise —, so the content takes it without
/// a word.
///
/// It keeps no state (`PillAction`, which says what a touch does): a touch on a
/// pill that can be chosen hands back the other value (`onToggle`), and the
/// caller passes it back as `isSelected`; the cross, or a touch anywhere on a
/// pill that can only be taken off, calls `onRemove`. A pill that does neither
/// takes no touch: the view holding it — a row that opens a client — gets it.
///
/// For VoiceOver, one element, read `accessibilityLabel` (the pill does not
/// know its content): a toggle, "Selected" or "Not selected", when it can be
/// chosen; a button when it can only be taken off; a "Remove" action when it
/// can be.
///
/// Not iOS's `Toggle(…).toggleStyle(.button)`: a pill both chosen and removable
/// carries two actions on one capsule. Not the search tokens
/// (`searchable(text:tokens:)`) either: they live in a search field.
///
/// Light only for now (the app is forced to light): once it is not, the chosen
/// fill and its foreground swap ink and paper.
///
/// ```swift
/// Pill(isSelected: draft.has(segment), accessibilityLabel: segment.title) { selected in
///     draft.set(segment, selected)
/// } content: {
///     Text(segment.title)
/// }
/// ```
struct Pill<Content: View>: View {
    /// Chosen or not; `nil` for a pill that cannot be chosen.
    var isSelected: Bool? = nil
    /// Whether it shows the cross that takes it off.
    var isRemovable = false
    /// What VoiceOver reads: the pill does not know its content.
    let accessibilityLabel: String
    /// The new value, on a touch, for a pill that can be chosen.
    var onToggle: ((Bool) -> Void)? = nil
    /// Taking it off: the cross, or a touch anywhere on a pill that can only
    /// be taken off.
    var onRemove: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    /// The cross as the mockup draws it, 7 pt, scaled like the text beside it.
    @ScaledMetric(relativeTo: .footnote) private var crossSize: CGFloat = 7

    // Computed: a generic type has no stored static property.

    /// The capsule, the mockup's: its least height, and its band's — Apple's
    /// tap target.
    private static var capsuleHeight: CGFloat { 36 }
    private static var bandHeight: CGFloat { 44 }
    /// The white of a pill not chosen, the mockup's 70 % — not the cards' 84
    /// (`OnCanvas.surface`).
    private static var restingOpacity: Double { 0.7 }
    /// The cross's box in the layout; its target is Apple's 44.
    private static var crossBox: CGFloat { 14 }

    var body: some View {
        // The default action only when a touch does something: an inert pill
        // offers VoiceOver nothing to activate, as it takes no touch.
        if action == .none {
            pill
        } else {
            pill.accessibilityAction { perform(action) }
        }
    }

    /// What a touch on the body does (`PillAction`).
    private var action: PillAction {
        PillAction.body(isSelected: isSelected, isRemovable: isRemovable)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            content()
            if isRemovable {
                cross
            }
        }
        .foregroundStyle(isSelected == true ? Color(.Base.paper) : Color(.OnSurface.textPrimary))
        .padding(.leading, 14)
        .padding(.trailing, isRemovable ? 10 : 14)
        .frame(minHeight: Self.capsuleHeight)
        .background(fill, in: .capsule)
        .frame(minHeight: Self.bandHeight)
        .contentShape(.rect)
        // A pill that does nothing leaves the touch to the view holding it.
        .gesture(TapGesture().onEnded { perform(action) }, isEnabled: action != .none)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(selectionValue)
        .accessibilityAddTraits(isSelected != nil ? .isToggle : (isRemovable ? .isButton : []))
        .accessibilityActions {
            if isRemovable {
                Button(String(localized: "Remove")) { onRemove?() }
            }
        }
    }

    private var fill: Color {
        isSelected == true ? Color(.Base.ink) : Color(.Base.paper).opacity(Self.restingOpacity)
    }

    /// The cross that takes it off, in the foreground's secondary level: the
    /// mockup's ink at 66 % on white, a softer paper on ink.
    private var cross: some View {
        Button {
            onRemove?()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: crossSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .tapTarget(drawnSize: Self.crossBox)
        }
        .buttonStyle(.plain)
    }

    /// "Selected" or "Not selected" for a pill that can be chosen; nothing
    /// otherwise.
    private var selectionValue: String {
        switch isSelected {
        case true?: String(localized: "Selected")
        case false?: String(localized: "Not selected")
        case nil: ""
        }
    }

    private func perform(_ action: PillAction) {
        switch action {
        case .none: break
        case .toggle(let value): onToggle?(value)
        case .remove: onRemove?()
        }
    }
}

// MARK: - Previews

#Preview("To pick, to take off") {
    @Previewable @State var picked: Set<String> = ["VIC"]
    @Previewable @State var filters = ["VIC", "Opted in on WhatsApp"]

    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 6) {
            ForEach(["VIC", "VIP", "Connoisseur"], id: \.self) { segment in
                Pill(isSelected: picked.contains(segment), accessibilityLabel: segment) { selected in
                    if selected { picked.insert(segment) } else { picked.remove(segment) }
                } content: {
                    Text(verbatim: segment).font(.subheadline.weight(.medium))
                }
            }
        }
        HStack(spacing: 6) {
            ForEach(filters, id: \.self) { filter in
                Pill(isRemovable: true, accessibilityLabel: filter, onRemove: {
                    filters.removeAll { $0 == filter }
                }) {
                    Text(verbatim: filter).font(.footnote.weight(.medium))
                }
            }
        }
        HStack(spacing: 6) {
            // Chosen and removable, a dot before its word, in its own stack.
            Pill(isSelected: true, isRemovable: true, accessibilityLabel: "Prospect") {
                HStack(spacing: 7) {
                    Circle().fill(Color.orange).frame(width: 10, height: 10)
                    Text(verbatim: "Prospect").font(.subheadline.weight(.medium))
                }
            }
            // Neither: it only shows.
            Pill(accessibilityLabel: "Paris Saint-Honoré") {
                Text(verbatim: "Paris Saint-Honoré").font(.subheadline.weight(.medium))
            }
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ambientBackground()
}
