//
//  PillAction.swift
//  FloorMobile
//

import Foundation

/// What a touch on a `Pill` does, from what the pill is: chosen or not, or not
/// choosable (`isSelected` `nil`), and removable or not. Apart from the view,
/// so the rule is tested without a screen.
///
/// | `isSelected`   | `isRemovable` | the body              | the cross |
/// |----------------|---------------|-----------------------|-----------|
/// | `nil`          | `false`       | nothing               | none      |
/// | `true`/`false` | `false`       | toggle to the other   | none      |
/// | `nil`          | `true`        | remove — the whole pill | remove  |
/// | `true`/`false` | `true`        | toggle to the other   | remove    |
nonisolated enum PillAction: Equatable, Sendable {
    /// The touch does nothing: a pill that only shows.
    case none
    /// The pill asks to be chosen (`true`) or let go (`false`): the caller
    /// passes the new value back as `isSelected`.
    case toggle(to: Bool)
    /// The pill asks to be taken off.
    case remove

    /// What a touch on the body of a pill does — the cross, when there is one,
    /// always removes.
    static func body(isSelected: Bool?, isRemovable: Bool) -> PillAction {
        if let isSelected { return .toggle(to: !isSelected) }
        return isRemovable ? .remove : .none
    }
}
