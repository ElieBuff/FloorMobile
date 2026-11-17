//
//  SheetBackground.swift
//  FloorMobile
//

import SwiftUI

extension View {
    /// The background of a sheet: the mockups' off-white (`Base.sheet`,
    /// #FAF7F2), plain — never the ambient background, which stays the
    /// screens' (decision of 17/11). iOS's own setting for a sheet's
    /// background (`presentationBackground`), with the scroll views' own
    /// background hidden so a list shows it. Apply it to the sheet's root
    /// view.
    ///
    /// "Voice search" and the signature sheet wear it; "Sort & filter" keeps
    /// the ambient background, as its mockup draws it.
    ///
    /// ```swift
    /// NavigationStack { … }
    ///     .sheetBackground()
    /// ```
    func sheetBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .presentationBackground(Color(.Base.sheet))
    }
}

// MARK: - Previews

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            Text(verbatim: "A sheet")
                .sheetBackground()
                .presentationDetents([.medium])
        }
}
