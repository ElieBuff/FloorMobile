//
//  ClientFilterSheet.swift
//  FloorMobile
//

import SwiftUI

/// "Filter" for "My Clients", opened from `ClientSearchControls` at half
/// height and closed with a swipe down. Empty for now: it will list the
/// tenant's filters (`ClientFilter`) and set the list's picked refs.
struct ClientFilterSheet: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle(Text("Filter"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Previews

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFilterSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
