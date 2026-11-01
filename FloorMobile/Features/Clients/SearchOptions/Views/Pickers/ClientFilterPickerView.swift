//
//  ClientFilterPickerView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Filter" for "My Clients", opened from `ClientSearchControls` as a sheet
/// at half height and closed with a swipe down. From top to bottom: the
/// sentence, its total and its pills (`ClientFilterBar`); the tenant's
/// filters (`ClientFilter`) in the server's order, each a section of values
/// to tick; "Apply".
///
/// Everything picked goes into a draft (`ClientFilterDraft`, held by
/// `ClientFilterEditor`), made from the list's filters once, in `init` —
/// `onAppear` would make it again on the way back from the calendar. Only
/// "Apply" writes its filters back; a swipe down drops them, and "Clear"
/// takes them all off.
struct ClientFilterPickerView: View {
    /// The list's options: written only by "Apply".
    @Binding var options: ClientSearchOptions
    /// Whose clients the list shows: the ones the total counts.
    let scope: ClientSearchScope

    @Query(sort: \ClientFilter.rank) private var filters: [ClientFilter]
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var editor: ClientFilterEditor
    /// The `ref` of the value the calendar is open for, while it is pushed —
    /// one calendar at a time, whatever the filter. Only the ref is kept: the
    /// draft finds the filter and the value by it once a day is confirmed
    /// (`ClientFilter.offering`).
    @State private var calendarRef: String?

    init(options: Binding<ClientSearchOptions>, scope: ClientSearchScope) {
        _options = options
        self.scope = scope
        _editor = State(initialValue: ClientFilterEditor(filters: options.wrappedValue.filters))
    }

    var body: some View {
        NavigationStack {
            filterList
                .safeAreaBar(edge: .top) {
                    ClientFilterBar(editor: editor)
                }
                .safeAreaBar(edge: .bottom) {
                    applyButton
                }
                .ambientBackground()
                .navigationTitle(Text("Filter"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        clearButton
                    }
                }
                .navigationDestination(item: $calendarRef, destination: calendar)
        }
        // On the stack, not on its first screen: pushing the calendar would
        // cancel them, and coming back start them again.
        .task(id: editor.draft.filters) {
            await editor.count(in: scope, session: session, services: services)
        }
        .task(id: editor.draft.pendingText) {
            await editor.fetchFilterItems(session: session, services: services)
        }
    }

    // MARK: - List

    /// The tenant's filters, each a section of its values, under their native
    /// headers — not `SectionHeader`, which titles the content sections of a
    /// scroll view (Home, Agenda), not a list's.
    ///
    /// "No filters yet" for a tenant whose filters were never written
    /// (FloorPlatform's `seed-client-filters.ts`): a sentence's pills apply
    /// all the same. No loading or error state: a local read of what
    /// `GET setup` saved before `RootView` shows the app.
    @ViewBuilder
    private var filterList: some View {
        if filters.isEmpty {
            ContentUnavailableView(
                String(localized: "No filters yet"),
                systemImage: "line.3.horizontal.decrease"
            )
        } else {
            List {
                ForEach(filters) { filter in
                    Section {
                        ForEach(filter.values, id: \.ref) { value in
                            row(for: value, of: filter)
                        }
                    } header: {
                        Text(filter.title)
                    }
                }
            }
            .cardList()
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// A value's row. A tap lets go of a ticked value, ticks one that asks
    /// for nothing — a filter that takes one value (`single`) lets go of the
    /// one it had —, and pushes the calendar for one that asks for a day.
    private func row(for value: ClientFilterValue, of filter: ClientFilter) -> some View {
        let isPicked = editor.draft.isPicked(value)
        return ClientFilterValueRow(value: value, isPicked: isPicked, day: editor.draft.day(pickedFor: value)) {
            if isPicked {
                editor.draft.unpick(value)
            } else if value.dateParameter != nil {
                calendarRef = value.ref
            } else {
                editor.draft.pick(value, of: filter)
            }
        }
    }

    // MARK: - Calendar

    /// The calendar pushed for the value `ref`, titled with its filter, which
    /// ticks the value once a day is confirmed. The closure keeps the ref, so
    /// the day comes back to the right value; going back sets `calendarRef`
    /// to nil.
    @ViewBuilder
    private func calendar(for ref: String) -> some View {
        if let filter = ClientFilter.offering(ref, in: filters) {
            ClientFilterDayPickerView(title: filter.title) { day in
                editor.draft.pick(day, forValue: ref, in: filters)
            }
        }
    }

    // MARK: - Buttons

    /// Takes every filter off, with what the last sentence left out or why
    /// its request failed; the field stays.
    private var clearButton: some View {
        Button(String(localized: "Clear")) {
            editor.draft.clear()
        }
        .disabled(!editor.draft.canClear)
    }

    /// "Apply", its label fixed — the total says itself under the sentence —:
    /// active while the total is counted, a hint rather than a gate, but
    /// waiting while a sentence's filters are on their way, for its pills.
    /// Writes the draft's filters into the list's options, which starts its
    /// search over, and closes the sheet.
    ///
    /// The list's search then fails ("Search failed") on a value the tenant
    /// removed since the app's launch (409 `filters_changed`), until it is
    /// unticked or the app relaunched, and on a pill whose condition the
    /// search refuses (400 `invalid_filters`), until it is taken off: both
    /// too rare to be worth the code.
    private var applyButton: some View {
        Button(String(localized: "Apply")) {
            options.filters = editor.draft.filters
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonSizing(.flexible)
        .disabled(editor.draft.hasPendingText)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Previews

#Preview(traits: .searchOptionsSampleData) {
    @Previewable @State var options = ClientSearchOptions()

    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFilterPickerView(options: $options, scope: .mine)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}
