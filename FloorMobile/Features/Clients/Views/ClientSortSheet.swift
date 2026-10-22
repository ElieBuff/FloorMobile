//
//  ClientSortSheet.swift
//  FloorMobile
//

import SwiftUI

/// "Sort by" for "My Clients", opened from `ClientSearchControls` at half
/// height and closed with a swipe down. Empty for now: it will list the
/// tenant's sorts (`ClientSort`) and set the list's sort and direction.
struct ClientSortSheet: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle(Text("Sort by"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Previews

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientSortSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
