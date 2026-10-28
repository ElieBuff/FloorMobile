//
//  ClientFilterPickerView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Filter" for "My Clients", opened from `ClientSearchControls` as a sheet
/// at half height and closed with a swipe down: the tenant's filters
/// (`ClientFilter`) in the server's order, each a section of the values it
/// offers, to tick (`CheckmarkRow`). A filter that takes one value (`single`)
/// lets go of the one it had; a value that asks for a day — "Since a date" —
/// pushes a calendar (`ClientFilterDayPickerView`) and is ticked once a day
/// is confirmed.
///
/// The ticks go into a draft, a copy of the list's options made once, in
/// `init` — `onAppear` would make it again on the way back from the
/// calendar —, and only "Apply" writes them back, which starts the list's
/// search over; a swipe down drops them, and "Clear" unticks everything.
///
/// "Apply" carries the draft's total once the ticks pause: one
/// `client/count` for the last state, as the route asks — a request given up
/// on runs on, server side. It counts what the filters keep in the list's
/// scope, whatever text is typed: how far the filters reach. The filters
/// only travel with `.mine` (`Endpoint.countClients`; the server refuses
/// them elsewhere): only "My Clients" opens this sheet, and a `.brand` total
/// would ignore them. Without a total — no connection, past the server's
/// limit, refused — "Apply" goes without a number, still active.
///
/// A 409 `filters_changed` — the tenant changed its filters since the app's
/// launch, which loads them (`GET setup`) — is deliberately not handled: too
/// rare to be worth the code. "Apply" then goes without a number, and the
/// list's search fails until the value gone is unticked or the app relaunched.
///
/// Empty for a tenant whose filters were never written (FloorPlatform's
/// `seed-client-filters.ts`). No loading or error state for the filters
/// themselves: a local read of what `GET setup` saved before `RootView`
/// shows the app.
///
/// The sections' native headers, not `SectionHeader`, which titles the
/// content sections of a scroll view (Home, Agenda), not a list's.
struct ClientFilterPickerView: View {
    /// The list's options: written only by "Apply".
    @Binding var options: ClientSearchOptions
    /// Whose clients the list shows: the ones the total counts.
    let scope: ClientSearchScope

    @Query(sort: \ClientFilter.rank) private var filters: [ClientFilter]
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    /// The picks being made.
    @State private var draft: ClientSearchOptions
    @State private var total = Total.counting
    /// The `ref` of the value the calendar is open for, while it is pushed —
    /// one calendar at a time, whatever the filter. A ref is unique across the
    /// tenant's filters: the sheet finds the filter and the value by it.
    @State private var calendarRef: String?

    /// How long the ticks must pause before the total is asked for: the
    /// search's own pause (`PagedSearchList`).
    private static let debounce: Duration = .milliseconds(300)

    /// "Apply", and the total once it is known.
    private var applyTitle: String {
        guard case .counted(let count) = total else { return String(localized: "Apply") }
        return String(localized: "Apply (\(count.formatted()))")
    }

    /// Where the draft's total stands.
    private enum Total: Equatable {
        case counting
        case counted(Int)
        /// Not counted: no connection, past the server's limit, or refused.
        case unknown
    }

    init(options: Binding<ClientSearchOptions>, scope: ClientSearchScope) {
        _options = options
        self.scope = scope
        _draft = State(initialValue: options.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Group {
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
                    .safeAreaBar(edge: .bottom) {
                        applyButton
                    }
                }
            }
            .ambientBackground()
            .navigationTitle(Text("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Clear")) {
                        draft.filters = []
                    }
                    .disabled(draft.filters.isEmpty)
                }
            }
            // A ref in `calendarRef` pushes the calendar for that value; the
            // closure it is handed keeps the ref, so the day confirmed comes
            // back to the right value. Going back sets `calendarRef` to nil.
            .navigationDestination(item: $calendarRef) { ref in
                if let filter = filter(offering: ref) {
                    ClientFilterDayPickerView(title: filter.title) { day in
                        pickDay(day, valueRef: ref)
                    }
                }
            }
        }
        // On the stack, not on its first screen: pushing the calendar would
        // cancel it, and coming back start it again.
        .task(id: draft.filters) {
            await count()
        }
    }

    // MARK: - Rows

    /// A value's row, ticked while the draft holds it. A tap lets go of a
    /// ticked value, ticks one that asks for nothing, and pushes the calendar
    /// for one that asks for a day.
    private func row(for value: ClientFilterValue, of filter: ClientFilter) -> some View {
        let isPicked = draft.isPicked(value)
        return CheckmarkRow(isChecked: isPicked) {
            if isPicked {
                draft.unpick(value)
            } else if value.dateParameter != nil {
                calendarRef = value.ref
            } else {
                draft.pick(value, of: filter)
            }
        } label: {
            Text(value.title)
        } accessory: {
            if value.dateParameter != nil {
                dayAccessory(for: value)
            }
        }
    }

    /// What follows a value that asks for a day: the day picked, or the
    /// chevron that says a tap opens the calendar.
    @ViewBuilder
    private func dayAccessory(for value: ClientFilterValue) -> some View {
        if let day = draft.day(pickedFor: value) {
            Text(day.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(Color(.OnSurface.textSecondary))
        } else {
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.OnSurface.textSecondary))
                .accessibilityHidden(true)
        }
    }

    /// Ticks the value the calendar confirmed a day for, found by its ref with
    /// its filter.
    private func pickDay(_ day: Date, valueRef: String) {
        guard let filter = filter(offering: valueRef),
              let value = filter.values.first(where: { $0.ref == valueRef }),
              let parameter = value.dateParameter
        else { return }
        draft.pick(value, of: filter, parameters: [parameter.name: day.calendarDay()])
    }

    /// The stored filter that offers the value `ref`, if any.
    private func filter(offering ref: String) -> ClientFilter? {
        filters.first { $0.values.contains { $0.ref == ref } }
    }

    // MARK: - Total

    /// "Apply", with the draft's total once counted — a hint, not a gate, so
    /// it stays active while counting: writes the draft's filters into the
    /// list's options, which starts its search over, and closes the sheet.
    private var applyButton: some View {
        Button {
            options.filters = draft.filters
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Text(applyTitle)
                if total == .counting {
                    ProgressView()
                        .accessibilityLabel(String(localized: "Counting clients"))
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .buttonSizing(.flexible)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Counts the draft's clients once the ticks pause. A newer tick cancels
    /// the wait — that total is never asked for — and what comes back for a
    /// count no longer wanted is dropped, as `PagedSearchList` does. Any
    /// failure, a 409 included, leaves "Apply" without a number.
    private func count() async {
        total = .counting
        do {
            try await Task.sleep(for: Self.debounce)
            let count = try await services.clients.countClients(
                nil, in: scope, filters: draft.filters, using: session.api
            )
            guard !Task.isCancelled else { return }
            total = .counted(count)
        } catch {
            guard !Task.isCancelled else { return }
            total = .unknown
        }
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
