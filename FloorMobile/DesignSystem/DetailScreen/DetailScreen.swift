//
//  DetailScreen.swift
//  FloorMobile
//

import SwiftUI

/// The chrome of a read-only detail presented modally: the app's backdrop, an
/// inline title, the list treatment its cards need, a close on the leading edge
/// and an "Edit" on the trailing one.
///
/// What `ComposerScreen` does for the two composers, this does for the two
/// details — it keeps screens that show different things from drifting apart,
/// while their fields stay entirely their own.
///
/// A cover rather than a push: an appointment or a task is an object *on* a
/// day, and opening one should not unbuild the day that was navigated to. The
/// `NavigationStack` belongs to the presenter, and that is what makes "Edit" a
/// step inside this modal instead of a second one stacked over it.
///
/// ```swift
/// fields.detailScreen(title: String(localized: "Task")) {
///     TaskComposerView(task: task)
/// }
/// ```
struct DetailScreen<Edit: View>: ViewModifier {
    let title: String
    /// The form "Edit" pushes, or `nil` for a record there is nothing left to
    /// change — which is what a row swept away by a sync shows.
    let edit: Edit?

    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .listRowBackground(Color(.OnCanvas.surface))
            .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
            // The list paints its own grey ground; the screen already has one.
            .scrollContentBackground(.hidden)
            .ambientBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // The same cross the composer wears at the root of its
                    // cover: one glyph, one meaning — this closes the modal.
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(String(localized: "Close"))
                }

                if let edit {
                    ToolbarItem(placement: .topBarTrailing) {
                        // A link rather than a button: the push, the tap
                        // target, the transition and the VoiceOver
                        // announcement all come with it — the same reasoning
                        // as `FormPushRow`.
                        NavigationLink(String(localized: "Edit")) { edit }
                    }
                }
            }
    }
}

extension View {
    /// Wraps this list of rows in a detail's chrome, with an "Edit" that pushes
    /// `edit` onto the modal's stack.
    func detailScreen<Edit: View>(title: String, @ViewBuilder edit: () -> Edit) -> some View {
        modifier(DetailScreen(title: title, edit: edit()))
    }

    /// The same chrome for a record with nothing left to edit.
    func detailScreen(title: String) -> some View {
        modifier(DetailScreen<EmptyView>(title: title, edit: nil))
    }
}
