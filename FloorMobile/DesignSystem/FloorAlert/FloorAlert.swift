//
//  FloorAlert.swift
//  FloorMobile
//

import SwiftUI

/// What an alert says and what it offers — the value a screen holds while a
/// dialog is up, and sets to `nil` when it is not.
///
/// `Identifiable` so a screen can drive the dialog from one optional piece of
/// state, the way `.sheet(item:)` works: putting a value in puts the dialog on
/// screen, and there is no second boolean to keep in step with it.
///
/// ```swift
/// @State private var alert: FloorAlert?
/// // …
/// .floorAlert($alert)
/// // …
/// alert = FloorAlert(
///     kind: .error,
///     title: String(localized: "Task not created"),
///     message: error.localizedDescription,
///     primary: AlertAction(label: String(localized: "Try again")) { save() },
///     secondary: AlertAction(label: String(localized: "Cancel"), emphasis: .quiet)
/// )
/// ```
struct FloorAlert: Identifiable {
    let id = UUID()

    var kind: AlertKind
    var title: String
    /// The sentence under the title. A title that already says everything is
    /// better off alone than padded with a restatement of itself.
    var message: String? = nil
    var primary: AlertAction
    /// The second button, or `nil` for an alert that only needs acknowledging.
    var secondary: AlertAction? = nil
}

// MARK: - Kind

/// What an alert is telling you, and the mark it wears to say so.
///
/// Three, deliberately. A fourth — "info" — would be a dialog that interrupts
/// to say nothing is wrong, which is a banner's job, not a modal's.
///
/// The colours are muted on purpose: they sit in the same family as the reason
/// palette rather than borrowing the system's saturated red. A dialog that
/// stops the advisor mid-task is already loud; the colour does not need to be.
enum AlertKind {
    /// Something will go wrong, or already did, and there is a choice to make.
    case warning
    /// It went wrong. Usually the end of an action that did not happen.
    case error
    /// It worked, and the advisor could not otherwise tell.
    case success

    var symbolName: String {
        switch self {
        case .warning: "exclamationmark.triangle.fill"
        case .error: "exclamationmark.octagon.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    /// The glyph's own colour.
    var fill: Color {
        switch self {
        case .warning: Color(.Status.Fill.warning)
        case .error: Color(.Status.Fill.error)
        case .success: Color(.Status.Fill.success)
        }
    }

    /// The same colour at 10%, for the glyph's backdrop — the `Fill`/`Tint`
    /// pairing the reason badges already use.
    var tint: Color {
        switch self {
        case .warning: Color(.Status.Tint.warning)
        case .error: Color(.Status.Tint.error)
        case .success: Color(.Status.Tint.success)
        }
    }
}

// MARK: - Action

/// One button on an alert: its label, how much weight it carries, and what it
/// does.
///
/// Grouped with the alert the way `EmptySectionAction` sits with its card, and
/// for the same reason — a button either has a complete definition or does not
/// exist. The label is a plain `String`: localization belongs to the call site
/// (design-system convention).
struct AlertAction {
    /// How loudly the button asks to be pressed.
    enum Emphasis {
        /// Filled, the one the dialog is steering towards. At most one.
        case prominent
        /// Filled faint — the way out, or the choice not being recommended.
        case quiet
    }

    var label: String
    var emphasis: Emphasis = .prominent
    /// Runs after the alert closes. An acknowledgement has nothing to run, so
    /// this defaults to nothing rather than forcing `{}` at every call site.
    var handler: () -> Void = {}
}
