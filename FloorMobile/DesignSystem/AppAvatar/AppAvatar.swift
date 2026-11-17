//
//  AppAvatar.swift
//  FloorMobile
//

import SwiftUI

/// The signed-in user's avatar, an `InitialsAvatar` of their name — Home's
/// header. Reads the session from the environment, so the screen needs no
/// parameters for it.
struct AppAvatar: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        // Alone in the bar, with no name beside it: it needs a label.
        InitialsAvatar(name: name, accessibilityLabel: String(localized: "Profile"))
    }

    private var name: String {
        if case .authenticated(let user) = session.state {
            return user.name
        }
        return ""
    }
}
