//
//  TaskActions.swift
//  FloorMobile
//

import SwiftUI

/// The writes a task's controls can trigger, and the state each one needs while
/// it is in flight.
///
/// Held as `@State` by whatever control triggers the write — `TaskCheckbox` in a
/// day's list, `TaskStatusSection` in the detail — so each one has its own. That
/// is the reason this is **not** a `Service`: a service in this app is built
/// once, injected at the root and shared by everything, which is exactly wrong
/// for state that belongs to one row on one screen. Two rows ticked in a row
/// would share a single pending value and a single alert.
///
/// The network and the store are not here either: `AgendaService` owns those.
/// What lives here is the choreography around them — show the change, ask the
/// server, put it back if the answer is no.
///
/// ## Why the optimistic value is safe
///
/// `pendingStatus` is never written anywhere. It exists so a control can paint
/// the tapped state while the request is out, because a tick that waits for a
/// round trip reads as a tick that missed the tap, and gets tapped again.
/// Clearing it *is* the entire rollback: the control falls back on what the row
/// says, and the row is what the failed request never changed.
///
/// One type for the task's writes rather than one per action: the next one —
/// deleting, snoozing — is a method here, not another file.
@Observable
final class TaskActions {
    /// A request is actually out on the network. Until then a tap is still
    /// yours to take back — see `grace`.
    private(set) var isWorking = false
    /// The status to paint while the server is asked, or waited for. Display
    /// only.
    private(set) var pendingStatus: TaskStatus?
    /// Raised when a write fails for good. `var` so the view's `.floorAlert`
    /// can clear it when the advisor dismisses the card.
    var alert: FloorAlert?

    /// The move that will be sent once the grace period is over, kept so a
    /// second tap can cancel it.
    private var scheduled: Task<Void, Never>?

    /// How long a tap waits before it is sent.
    ///
    /// The mark changes at once, and the row keeps its place for a beat — long
    /// enough to notice a mis-tap and take it back, and short enough that the
    /// list does not feel stuck. Nothing leaves the device during that beat, so
    /// changing your mind costs the server nothing.
    ///
    /// It also debounces the detail's three-way control: tapping through states
    /// sends only the one you land on.
    ///
    /// Injectable so a test can shorten it: the controls take the default, and
    /// a suite that means to cross the window does not have to spend a real
    /// second per case doing it.
    let grace: Duration

    init(grace: Duration = .seconds(1)) {
        self.grace = grace
    }

    /// What a control should paint: the tap if one is in flight, the stored row
    /// otherwise.
    func shownStatus(over stored: TaskStatus) -> TaskStatus {
        pendingStatus ?? stored
    }

    /// The row caught up — with this tap, or with something else the server
    /// decided. Either way the optimistic value has served its turn.
    ///
    /// Returns whether anything was actually dropped, so a caller that animates
    /// the change does not open a transaction for a value that had already
    /// settled — animating that restarts a slide mid-flight.
    @discardableResult
    func settle() -> Bool {
        guard pendingStatus != nil else { return false }
        pendingStatus = nil
        return true
    }

    /// Moves the task to `status`: paints it at once, sends it a beat later.
    ///
    /// A `PATCH` on the status alone, not a save: ticking a task must not carry
    /// along whatever else the row happens to hold.
    ///
    /// A second tap within the grace period replaces the first — the scheduled
    /// move is cancelled and nothing was ever sent. A tap that lands back on
    /// the status the row already holds sends nothing at all and simply stops
    /// painting.
    ///
    /// Once the request is out it is too late: `isWorking` turns the control
    /// down rather than racing two writes on one task.
    ///
    /// `onChange` runs around the moments a caller may want to animate — the
    /// optimistic paint and its rollback. `TaskStatusSection` slides a pill
    /// through it; `TaskCheckbox` has nothing to animate and leaves it out.
    func move(
        _ id: String,
        to status: TaskStatus,
        stored: TaskStatus,
        session: AppSession,
        services: AppServices,
        // Escaping: the paint and its rollback both run inside the `Task`
        // below, after the call has already returned.
        onChange: @escaping (() -> Void) -> Void = { $0() }
    ) {
        guard !isWorking else { return }
        // Whatever was waiting is void: this tap is the one that counts.
        scheduled?.cancel()

        // Back to where the row already is — so there is nothing to send, and
        // nothing left to paint over it.
        guard status != stored else {
            onChange { pendingStatus = nil }
            return
        }
        onChange { pendingStatus = status }

        let api = session.api
        let agenda = services.agenda

        scheduled = Task {
            do {
                try await Task.sleep(for: grace)
            } catch {
                // Cancelled by a later tap, which has already painted its own
                // value and scheduled its own send. Nothing to undo.
                return
            }

            // Past the point of no return: the control goes quiet while the
            // request is out.
            isWorking = true
            do {
                try await agenda.updateTaskStatus(id: id, to: status, using: api)
            } catch {
                onChange { pendingStatus = nil }
                alert = FloorAlert(
                    kind: .error,
                    title: String(localized: "Status not changed"),
                    message: error.localizedDescription,
                    // Weakly: the alert is held by `self`, so a retry closure
                    // that held `self` back would be a cycle — and this object
                    // lives exactly as long as the control that owns it.
                    primary: AlertAction(label: String(localized: "Try again")) { [weak self] in
                        self?.move(
                            id, to: status, stored: stored,
                            session: session, services: services, onChange: onChange
                        )
                    },
                    secondary: AlertAction(label: String(localized: "Close"), emphasis: .quiet)
                )
            }
            isWorking = false
        }
    }
}
