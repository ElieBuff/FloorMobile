//
//  LoginView.swift
//  FloorMobile
//

import SwiftUI

/// Sign-in screen: a single button opening the Zitadel login page.
struct LoginView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("FloorMobile")
                .font(.largeTitle.bold())
            Text("Sign in to access your store data.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if case .failed(let message) = session.state {
                Text(message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await session.signIn() }
            } label: {
                if session.state == .authenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session.state == .authenticating)
        }
        .padding(24)
    }
}

#Preview {
    LoginView()
        .environment(AppSession(auth: .preview))
}
