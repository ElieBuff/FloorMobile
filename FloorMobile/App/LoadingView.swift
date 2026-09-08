//
//  LoadingView.swift
//  FloorMobile
//
//  Created by elie buff on 07/09/2026.
//

import SwiftUI

/// Loading screen displayed while data is being synchronized.
struct LoadingView: View {
    /// Message describing the current synchronization state.
    let message: String

    /// Retry action, provided only when the synchronization failed.
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
           
            Text("FloorMobile")
                .font(.largeTitle.bold())

            if let retryAction {
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Réessayer", action: retryAction)
                    .buttonStyle(.borderedProminent)
            } else {
                ProgressView()
                    .controlSize(.large)

                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Chargement") {
    LoadingView(message: "Synchronisation des données…")
}

#Preview("Erreur") {
    LoadingView(message: "Échec de la synchronisation.", retryAction: {})
}
