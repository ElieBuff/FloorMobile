//
//  ComposerSheet.swift
//  FloorMobile
//

import SwiftUI

/// The chrome of a form presented modally: the app's backdrop, an inline title,
/// a way out on the leading edge and a confirm on the trailing one.
///
/// Its job is to keep two forms that write different things from drifting
/// apart — same placement, same glyphs, same disabled rule, same behaviour
/// while a save is out — while their fields, their drafts and their save paths
/// stay entirely separate.
///
/// It does **not** provide the `NavigationStack`: the presenter does. The same
/// form is the first screen of its own cover when creating, and a step pushed
/// onto a detail when editing — and a stack nested in a stack would break that
/// push. `Placement` is how the form says which of the two it is.
///
/// ```swift
/// List { /* the fields */ }
///     .composerScreen(title: "New Task", placement: .root, canSave: draft.isValid,
///                     isDirty: draft != original, isSaving: isSaving) { save() }
/// ```
struct ComposerScreen: ViewModifier {
    /// Where the form sits in the modal it belongs to.
    enum Placement {
        /// Its first screen — leaving closes the whole thing.
        case root
        /// A step pushed onto a detail already in the modal — leaving goes back
        /// to that detail.
        case pushed
    }

    let title: String
    let placement: Placement
    /// Gates the confirm button. A form that lets you confirm an incomplete
    /// thing has to explain itself afterwards; one that waits does not.
    let canSave: Bool
    /// Whether the form holds anything that leaving would throw away.
    let isDirty: Bool
    /// Whether the save is out on the network.
    ///
    /// The confirm button *becomes* the progress indicator rather than sitting
    /// next to one: a checkmark that stays put while something happens reads as
    /// a button that did not register the tap, and gets tapped again.
    let isSaving: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var discard: FloorAlert?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ambientBackground()
            // Not decoration: `disabled` stops a focused field from taking
            // further keystrokes, and the scrim swallows taps on the rows
            // underneath — what is on screen is on its way to the server.
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    Color(.Base.ink)
                        .opacity(0.12)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .animation(.smooth(duration: 0.2), value: isSaving)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            // The first screen of a cover has no back button to hide; this is
            // for the pushed form, whose chevron cannot be intercepted and
            // whose swipe-back would take the edits with it without a word.
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { leave() } label: {
                        Image(systemName: placement.leaveSymbol)
                    }
                    // Leaving mid-flight would abandon a save with nowhere
                    // left to report a failure.
                    .disabled(isSaving)
                    .accessibilityLabel(placement.leaveLabel)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                            .accessibilityLabel(String(localized: "Saving"))
                    } else {
                        Button { onSave() } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(!canSave)
                        .accessibilityLabel(String(localized: "Save"))
                    }
                }
            }
            .floorAlert($discard)
    }

    /// Leaves the form — straight away when there is nothing to lose, after
    /// asking when there is.
    ///
    /// One `dismiss()` for both placements, and it is the placement that gives
    /// it its meaning: at the root it closes the modal, pushed it steps back to
    /// the detail underneath.
    private func leave() {
        guard isDirty else {
            dismiss()
            return
        }
        discard = FloorAlert(
            kind: .warning,
            title: String(localized: "Leave without saving?"),
            message: String(localized: "What you typed will not be kept."),
            primary: AlertAction(label: String(localized: "Discard")) { dismiss() },
            secondary: AlertAction(label: String(localized: "Keep editing"), emphasis: .quiet)
        )
    }
}

// MARK: - Placement

private extension ComposerScreen.Placement {
    /// The mark on the way out: closing the modal, or stepping back inside it.
    /// A cross where a chevron belongs would promise to close everything while
    /// only going back one screen.
    var leaveSymbol: String {
        switch self {
        case .root: "xmark"
        case .pushed: "chevron.backward"
        }
    }

    /// What the glyph says out loud, since an icon alone says nothing to a
    /// screen reader.
    var leaveLabel: String {
        switch self {
        case .root: String(localized: "Close")
        case .pushed: String(localized: "Back")
        }
    }
}

extension View {
    /// Wraps this form in a composer's chrome. The presenter supplies the
    /// `NavigationStack` — see `ComposerScreen`.
    func composerScreen(
        title: String,
        placement: ComposerScreen.Placement,
        canSave: Bool,
        isDirty: Bool,
        isSaving: Bool,
        onSave: @escaping () -> Void
    ) -> some View {
        modifier(ComposerScreen(
            title: title,
            placement: placement,
            canSave: canSave,
            isDirty: isDirty,
            isSaving: isSaving,
            onSave: onSave
        ))
    }
}

// MARK: - Previews

/// A stand-in for a real composer: enough rows to see the scrim over them, a
/// save that takes its time so the loading state can be watched rather than
/// only described, and a title it remembers opening on so the guard that asks
/// before discarding can be tried out.
private struct ComposerScreenPreview: View {
    let placement: ComposerScreen.Placement

    private static let openedOn = "Rappeler Mme Dupont"

    @State private var title = Self.openedOn
    @State private var isSaving = false

    var body: some View {
        List {
            Section {
                FormTitleRow(label: String(localized: "Title"), text: $title)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                FormPushRow(label: String(localized: "Client"), value: "Léa Bonnet") {
                    Text(verbatim: "Clients")
                }
                .listRowInsets(.cardRow)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .listRowBackground(Color(.OnCanvas.surface))
        .scrollContentBackground(.hidden)
        .composerScreen(
            title: String(localized: "New Task"),
            placement: placement,
            canSave: !title.isEmpty,
            isDirty: title != Self.openedOn,
            isSaving: isSaving
        ) {
            isSaving = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                isSaving = false
            }
        }
    }
}

// The chrome no longer carries a stack, so the presenter provides one — here,
// the preview.
#Preview("At the root of its cover") {
    NavigationStack {
        ComposerScreenPreview(placement: .root)
    }
    .tint(Color(.Base.ink))
}

// Tap "Edit" to reach the pushed chrome: a chevron rather than a cross, and no
// system back button behind it.
#Preview("Pushed from a detail") {
    NavigationStack {
        List {
            NavigationLink(String(localized: "Edit")) {
                ComposerScreenPreview(placement: .pushed)
            }
        }
        .navigationTitle(Text(verbatim: "Event"))
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(Color(.Base.ink))
}
