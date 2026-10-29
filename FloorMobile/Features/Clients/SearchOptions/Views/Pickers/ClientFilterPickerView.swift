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
/// Above them, pinned, the sentence: the clients wanted in the associate's
/// own words, typed or dictated (`FormDictateButton`, `.transcription`), what
/// is dictated added after what is there (`String.append(dictation:)`).
/// Pinned on the whole sheet, so over "No filters yet" too: a sentence gives
/// conditions of its own, outside the catalog. The arrow sends it to be read
/// (`ClientService.filterItems(from:using:)`), for up to 80 s: the filters it
/// describes become pills under the card (`Pill`), in place of the last
/// sentence's, and what no filter covers is said under them. The sentence
/// goes with the sheet, sent or not — "Apply" takes the ticks and the pills,
/// never the field —; its pills, once applied, stay with the list.
///
/// The ticks and the pills go into a draft, a copy of the list's options made
/// once, in `init` — `onAppear` would make it again on the way back from the
/// calendar —, and only "Apply" writes them back, which starts the list's
/// search over; a swipe down drops them, and "Clear" takes them all off, with
/// what the last reading left out, the sentence left in its field.
///
/// "Apply" carries the draft's total once the ticks pause: one
/// `client/count` for the last state, as the route asks — a request given up
/// on runs on, server side. It counts what the filters keep in the list's
/// scope, whatever text is typed: how far the filters reach. The filters
/// only travel with `.mine` (`Endpoint.countClients`; the server refuses
/// them elsewhere): only "My Clients" opens this sheet, and a `.brand` total
/// would ignore them. Without a total — no connection, past the server's
/// limit, refused — "Apply" goes without a number, still active. While a
/// sentence is read, "Apply" waits: its pills would be left behind.
///
/// A 409 `filters_changed` — the tenant changed its filters since the app's
/// launch, which loads them (`GET setup`) — is deliberately not handled: too
/// rare to be worth the code. "Apply" then goes without a number, and the
/// list's search fails until the value gone is unticked or the app relaunched.
/// Nor is a pill whose condition the search refuses (400 `invalid_filters`),
/// though the server wrote it a moment before: the list shows "Search failed"
/// until the pill is taken off here.
///
/// No filters yet, between the sentence above and "Apply" below, for a tenant
/// whose filters were never written (FloorPlatform's `seed-client-filters.ts`):
/// a sentence's pills apply all the same. No loading or error state for the
/// filters themselves: a local read of what `GET setup` saved before
/// `RootView` shows the app.
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
    /// The clients wanted, in the associate's words: what the arrow sends.
    @State private var sentence = ""
    /// The sentence being read, from the arrow to the server's answer, which
    /// `.task(id: reading)` waits for; `nil` the rest of the time.
    @State private var reading: String?
    /// What the last sentence read left uncovered, said under its pills.
    @State private var notUnderstood: [String] = []
    /// Why the last reading failed, said under the card until the next one.
    @State private var readingFailure: String?
    @State private var isDictating = false
    @FocusState private var isSentenceFocused: Bool

    /// How long the ticks must pause before the total is asked for: the
    /// search's own pause (`PagedSearchList`).
    private static let debounce: Duration = .milliseconds(300)
    /// The arrow's size in the layout, the microphone's beside it.
    private static let sendSize: CGFloat = 32

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
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .safeAreaBar(edge: .top) {
                sentenceBar
            }
            .safeAreaBar(edge: .bottom) {
                applyButton
            }
            .ambientBackground()
            .navigationTitle(Text("Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Clear")) {
                        draft.filters = []
                        notUnderstood = []
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
        // cancel them, and coming back start them again.
        .task(id: draft.filters) {
            await count()
        }
        .task(id: reading) {
            await read()
        }
    }

    // MARK: - Sentence

    /// The sentence's card, then the draft's pills — the last sentence read's,
    /// in this sheet or applied before —, what that sentence left uncovered,
    /// and why the last reading failed, each when there is one.
    private var sentenceBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            sentenceField
            if !draft.filterItems.isEmpty {
                pills
            }
            if !notUnderstood.isEmpty {
                note(Text("Not understood: \(notUnderstood, format: .list(type: .and))"))
            }
            if let readingFailure {
                note(Text(readingFailure))
            }
        }
        .padding(.bottom, 8)
    }

    /// The sentence, in a card pinned above the filters, or "No filters yet":
    /// up to four lines, so a dictated one reads whole, then the microphone,
    /// and the arrow once there are words. A tap anywhere on the card puts the
    /// caret in the text, as in `FormTitleRow`. Not `FormTitleRow` or
    /// `FormNoteRow`: a bar wants neither a label nor a reserved height.
    private var sentenceField: some View {
        HStack(spacing: 9) {
            TextField(String(localized: "Describe the clients you want"), text: $sentence, axis: .vertical)
                .lineLimit(1...4)
                .font(.body)
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .focused($isSentenceFocused)
            FormDictateButton {
                isDictating = true
            }
            sendButton
        }
        .padding(.horizontal, AppSpacing.cardInset)
        .padding(.vertical, 10)
        .cardStyle()
        .contentShape(.rect)
        .onTapGesture { isSentenceFocused = true }
        .padding(.horizontal, 16)
        .transcription(isPresented: $isDictating) { text in
            sentence.append(dictation: text)
        }
    }

    /// The arrow that sends the sentence to be read, once it has words; a
    /// spinner in its place while it is read.
    @ViewBuilder
    private var sendButton: some View {
        if reading != nil {
            ProgressView()
                .frame(width: Self.sendSize, height: Self.sendSize)
                .accessibilityLabel(String(localized: "Reading the sentence"))
        } else if !trimmedSentence.isEmpty {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(.Base.ink))
                    .tapTarget(drawnSize: Self.sendSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Send"))
        }
    }

    /// The sentence as the arrow sends it: trimmed, so spaces and line breaks
    /// alone bring no arrow.
    private var trimmedSentence: String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The pills of the sentence read, on one line that scrolls, each with an
    /// X that takes its filter off the draft.
    private var pills: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(draft.filterItems) { item in
                    Pill(label: item.label) {
                        draft.remove(item)
                    }
                }
            }
            // Room for each X's 44pt target, as `Pill` asks: a scroll view
            // takes no tap past its edges.
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    /// A line under the card about the last reading: what it left out, or why
    /// it failed.
    private func note(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(Color(.OnCanvas.textSecondary))
            .padding(.horizontal, 16)
    }

    /// Hands the sentence to the reading — `.task(id: reading)` reads it —,
    /// and puts the keyboard away, for the pills to come.
    private func send() {
        readingFailure = nil
        reading = trimmedSentence
        isSentenceFocused = false
    }

    /// Reads the sentence sent, and puts the filters it describes in place of
    /// the last sentence's pills, the ticks left as they are; what no filter
    /// covers goes under them. Closing the sheet cancels it, and what comes
    /// back then is dropped. A failure leaves the pills as they were. Done
    /// either way, it gives the arrow and "Apply" back.
    private func read() async {
        guard let reading else { return }
        do {
            let answer = try await services.clients.filterItems(from: reading, using: session.api)
            guard !Task.isCancelled else { return }
            draft.replaceFilterItems(with: answer.items)
            notUnderstood = answer.notUnderstood
        } catch {
            guard !Task.isCancelled else { return }
            // Any network error — no connection, or a server silent past the
            // request's 90 s — says the same, as in
            // `MyClientsList.failedFirstPage`: the screen does not look into
            // `AppError.network`'s underlying error.
            readingFailure = if case .network? = error as? AppError {
                String(localized: "Reading a sentence needs a connection")
            } else {
                String(localized: "Couldn't read the sentence. Try again.")
            }
        }
        self.reading = nil
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
    /// it stays active while counting, but waits while a sentence is read, for
    /// its pills: writes the draft's filters into the list's options, which
    /// starts its search over, and closes the sheet.
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
        .disabled(reading != nil)
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
