//
//  AgendaPresentation.swift
//  FloorMobile
//

import SwiftUI

/// What an agenda cover has open, or `nil` when it is closed.
///
/// A routing value rather than a flag: the "+" chooses what to create and the
/// cover opens straight onto it instead of asking again, and a tapped row opens
/// on the thing it is about. Four cases and one presentation, because a detail
/// and the form that edits it are one flow — not two modals stacked up.
///
/// Deliberately *not* a `HomeRoute` case, and the reason is written down there:
/// a task and an appointment are objects on a day rather than places of their
/// own. A route also has to stay `Codable` to survive a relaunch for state
/// restoration and deep links, which a half-filled form is not.
///
/// Shared by every screen that shows the agenda's objects — the agenda itself
/// and Home's sections — so one row opens the same way wherever it is read.
nonisolated enum AgendaPresentation: Hashable, Identifiable {
    case newEvent
    case newTask
    case event(id: String)
    case task(id: String)

    /// The value is its own identity, which is what `fullScreenCover(item:)`
    /// reads to decide whether to rebuild its content: another case, or the
    /// same case on another row, is another thing to show. Spelling the ids out
    /// by hand would mean keeping `event` and `task` from colliding on a shared
    /// identifier through a naming convention; here they cannot.
    var id: Self { self }
}

/// The screen one `AgendaPresentation` opens.
///
/// The `NavigationStack` belongs to the cover, not to the screens inside it:
/// that is what lets a detail push its own form as a step rather than stack a
/// second modal over itself.
///
/// One view for every caller, so Home and the agenda open the same thing by the
/// same path — and a case added above is wired once, right here, where leaving
/// it out will not compile. `date` seeds the composers, and is the only way the
/// callers differ: the agenda creates on the day it is showing, Home on today.
struct AgendaPresentationScreen: View {
    let presentation: AgendaPresentation
    let date: Date

    var body: some View {
        NavigationStack {
            switch presentation {
            case .newEvent: EventComposerView(date: date)
            case .newTask: TaskComposerView(date: date)
            case .event(let id): EventDetailView(id: id)
            case .task(let id): TaskDetailView(id: id)
            }
        }
    }
}
