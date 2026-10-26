//
//  ClientFilterPickerView.swift
//  FloorMobile
//

import SwiftUI

/// "Filter" for "My Clients", opened from `ClientSearchControls` as a sheet
/// at half height and closed with a swipe down. Empty for now: it will list
/// the tenant's filters (`ClientFilter`) and set the list's picked values
/// (`ClientFilterChoice`).
struct ClientFilterPickerView: View {
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
            ClientFilterPickerView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
