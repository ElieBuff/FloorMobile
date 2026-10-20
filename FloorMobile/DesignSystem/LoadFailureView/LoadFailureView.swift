//
//  LoadFailureView.swift
//  FloorMobile
//

import SwiftUI

/// What a screen shows in place of what it could not load: a title saying
/// what failed, the error's own message, and "Try again", which hands back to
/// the caller to start the load again.
///
/// One view for every load that fails as a whole — a list's first page ("All
/// Brand"), a client's profile — so they read alike and cannot drift apart.
/// Native inside: a `ContentUnavailableView`.
///
/// ```swift
/// LoadFailureView(title: String(localized: "Search failed"), error: failure.error) {
///     failedSearch = nil   // the list is built afresh, and asks again
/// }
/// ```
struct LoadFailureView: View {
    /// What failed, e.g. "Search failed".
    let title: String
    let error: any Error
    /// Starts the load again — usually by clearing the error the screen
    /// shows this view for, which brings its loading branch back.
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button(String(localized: "Try again"), action: retry)
        }
    }
}

// MARK: - Previews

#Preview {
    LoadFailureView(
        title: "Couldn't load this client",
        error: AppError.network(underlying: nil)
    ) {}
    .ambientBackground()
}
