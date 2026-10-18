//
//  CardList.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// The app's list look: inset-grouped cards on the `OnCanvas.surface`
    /// fill, subtle separators, and no system background — so the screen's
    /// `ambientBackground()` shows through. Apply to a `List`.
    func cardList() -> some View {
        self
            .listStyle(.insetGrouped)
            .listRowBackground(Color(.OnCanvas.surface))
            .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
            .scrollContentBackground(.hidden)
    }
}
