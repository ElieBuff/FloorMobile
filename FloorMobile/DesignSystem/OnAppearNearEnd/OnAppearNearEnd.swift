//
//  OnAppearNearEnd.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// Runs `action` when this row — `item`, one of `items` — appears among
    /// the last `distance` of them: the moment a list that loads page by page
    /// should ask for the next one, early enough that it is usually there
    /// before the bottom is reached.
    ///
    /// Fires once per row appearance, so the action must ignore a request it
    /// is already serving.
    func onAppearNearEnd<Item: Identifiable>(
        of items: [Item],
        item: Item,
        distance: Int = 10,
        perform action: @escaping () -> Void
    ) -> some View {
        onAppear {
            if items.suffix(distance).contains(where: { $0.id == item.id }) {
                action()
            }
        }
    }
}
