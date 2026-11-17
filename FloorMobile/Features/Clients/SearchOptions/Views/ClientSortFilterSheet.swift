//
//  ClientSortFilterSheet.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Sort & filter" for the Clients tab's list, opened by the bar's button
/// (`ClientsView`). From top to bottom: the close button, the title and
/// "Clear"; the sentence; "Sort by"; the tenant's filters (`ClientFilter`) in
/// the server's order, each a group of pills (`ClientFilterGroup`); "Show N
/// clients".
///
/// Everything picked goes into a draft (`ClientFilterDraft`, held by
/// `ClientFilterEditor`), made from the list's options once, in `init` —
/// `onAppear` would make it again on the way back from the calendar. Only
/// "Show" writes them back, and closes the sheet; the close button and a
/// swipe down drop them. "Clear" puts the server's default sort back and
/// takes the filters off, in the draft.
///
/// For now (decisions of 16/11 and 17/11): the sentence is only drawn.
struct ClientSortFilterSheet: View {
    /// The list's options: written only by "Show".
    @Binding var options: ClientSearchOptions

    @Query(sort: \ClientSort.rank) private var sorts: [ClientSort]
    @Query(sort: \ClientFilter.rank) private var filters: [ClientFilter]
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var editor: ClientFilterEditor
    /// Whether "Voice search" is open, from the sentence's microphone.
    @State private var isDictating = false
    /// The `ref` of the value the calendar is open for, while it is pushed —
    /// one calendar at a time, whatever the filter. Only the ref is kept: the
    /// draft finds the filter and the value by it once a day is confirmed
    /// (`ClientFilter.offering`).
    @State private var calendarRef: String?
    @FocusState private var isSentenceFocused: Bool
    /// The sentence's line: 22 pt, iOS's for `.body` and the mockup's, scaled
    /// like the text — what the pebble and the buttons sit on.
    @ScaledMetric(relativeTo: .body) private var sentenceLineHeight: CGFloat = 22

    /// The pebble beside the sentence: 18 pt (decision of 16/11), where the
    /// mockup draws 14 beside a 15 pt text — the sentence is in 17.
    private static let pebbleSize: CGFloat = 18
    /// Between the sentence's card and "Sort by"'s, the mockup's.
    private static let sectionSpacing: CGFloat = 12
    /// Between the sentence's cross and its arrow's 32 pt boxes: about 16 pt
    /// between their discs, the mockup's (decision of 17/11, 12 read wide);
    /// their 44 pt targets overlap by 2.
    private static let sentenceButtonSpacing: CGFloat = 10
    /// Around a filter's group, the mockup's: 14 pt above its title, 10
    /// under its pills, and 20 from the screen's edges — 4 past the list's
    /// 16.
    private static let filterRowInsets = EdgeInsets(top: 14, leading: 4, bottom: 10, trailing: 4)

    init(options: Binding<ClientSearchOptions>) {
        _options = options
        _editor = State(initialValue: ClientFilterEditor(options: options.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    sentence
                        .insetGroupedRow()
                }
                // A tenant without sorts has no "Sort by".
                if !sorts.isEmpty {
                    Section {
                        sortPicker
                            .insetGroupedRow()
                    }
                }
                // A tenant without filters has none to show.
                if !filters.isEmpty {
                    Section {
                        ForEach(filters) { filter in
                            filterRow(for: filter)
                        }
                    }
                }
            }
            .insetGroupedList()
            .listSectionSpacing(Self.sectionSpacing)
            .scrollDismissesKeyboard(.immediately)
            // On the list rather than on the sentence's row: a sheet inside
            // a lazy container may never present. At half height, as the
            // mockup draws it over this sheet.
            .sheet(isPresented: $isDictating) {
                ClientVoiceSearchSheet { dictated in
                    editor.draft.text.append(dictation: dictated)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .safeAreaBar(edge: .bottom) {
                showButton
            }
            .ambientBackground()
            .navigationTitle(Text("Sort & filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(item: $calendarRef, destination: calendar)
        }
        // The filters only: a sort changes no total (`ClientFilterEditor.count`).
        // On the stack, not on its first screen: pushing the calendar would
        // cancel the count, and coming back start it again.
        .task(id: editor.draft.options.filters) {
            await editor.count(session: session, services: services)
        }
    }

    // MARK: - Sentence

    /// The sentence: Tolby's pebble, then the clients wanted in the
    /// associate's own words, typed or said, and at its end (decisions of
    /// 16/11):
    /// - the field empty, the microphone, which opens "Voice search"
    ///   (`ClientVoiceSearchSheet`) — what is said is added after what is
    ///   there (`String.append(dictation:)`), which fills the empty field;
    /// - the field written, the cross that empties it, where the microphone
    ///   was, and the arrow that will send it.
    ///
    /// Only drawn for now: the arrow sends nothing, and the sentence goes with
    /// the sheet; reading it for its filters (`ClientFilterDraft.send`,
    /// `ClientFilterEditor.fetchFilterItems`) comes with the arrow's call.
    ///
    /// Up to three lines, then the text scrolls inside the field (decision of
    /// 17/11, the mockup's ceiling); a tap anywhere on the row puts the caret
    /// in the text, as in `FormTitleRow`. Not that row, nor `FormTextRow`: a
    /// sentence wants neither a label nor a reserved height. In 17 pt, iOS's
    /// size for a row's text, where the mockup writes 15 (decision of 16/11:
    /// 15 read small on screen); the buttons follow.
    ///
    /// On a line of `sentenceLineHeight`, as the mockup lays it out: the
    /// pebble beside the first line, the cross and the arrow — or the
    /// microphone — beside the last, each in a frame one line high, which
    /// their larger boxes and targets overflow unclipped. Five points above
    /// and below keep the first line 15 pt from the card's top at every
    /// height, the mockup's: the row gives 10, and the buttons' 32 pt box,
    /// past the line, would give the rest on one line only.
    private var sentence: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                IntelligencePebble(size: Self.pebbleSize)
                    .frame(height: sentenceLineHeight)
                TextField(
                    String(localized: "Describe the clients you want"),
                    text: $editor.draft.text,
                    axis: .vertical
                )
                .lineLimit(1...3)
                .font(.body)
                .lineHeight(.exact(points: sentenceLineHeight))
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .focused($isSentenceFocused)
                // Sliding the text back to its start keeps the keyboard: the
                // list closes it as soon as it scrolls, and this setting may
                // reach the field's own scrolling.
                .scrollDismissesKeyboard(.never)
            }
            sentenceButtons
                .frame(height: sentenceLineHeight)
        }
        .padding(.vertical, 5)
        .contentShape(.rect)
        .onTapGesture { isSentenceFocused = true }
    }

    /// The microphone while the field is empty; the cross and the arrow once
    /// it is written, `sentenceButtonSpacing` apart.
    @ViewBuilder
    private var sentenceButtons: some View {
        if editor.draft.text.isEmpty {
            FieldIconButton(
                systemImage: "mic",
                label: String(localized: "Dictate"),
                font: .body,
                color: Color(.OnSurface.textPrimary)
            ) {
                isDictating = true
            }
        } else {
            HStack(spacing: Self.sentenceButtonSpacing) {
                FieldIconButton(
                    systemImage: "xmark.circle.fill",
                    label: String(localized: "Clear text"),
                    font: .body
                ) {
                    editor.draft.text = ""
                }
                // `.title`: a 33 pt disc, iOS's nearest to the mockup's 32
                // (decision of 17/11; `.title3` drew 23).
                FieldIconButton(
                    systemImage: "arrow.up.circle.fill",
                    label: String(localized: "Send"),
                    font: .title,
                    color: Color(.OnSurface.textPrimary)
                ) {
                    // Nothing yet (decision of 16/11): it will read the
                    // sentence's filters — `ClientFilterDraft.send`, then
                    // `ClientFilterEditor.fetchFilterItems`.
                }
            }
        }
    }

    // MARK: - Sort

    /// "Sort by": the system's menu, which opens in place and ticks the sort
    /// the search runs, holding the sorts' `Picker` inline — the tenant's
    /// sorts (`ClientSort`) in the server's order, each in the direction it
    /// starts in (`ClientSearchOptions.pick`): the server takes both, the
    /// mockup draws none.
    ///
    /// Its label is the app's, as the mockup draws it (decision of 16/11,
    /// chosen on screen among five): the title in Medium ink, the sort and
    /// the chevrons in grey. A `Picker` in `.menu` style draws its value and
    /// chevrons in the app's tint — ink —, title and value alike. In 17 pt,
    /// as the sentence above, where the mockup writes 15. The row keeps
    /// iOS's height — 55 pt measured on iOS 27.2, the mockup's 54.
    private var sortPicker: some View {
        Menu {
            Picker(selection: sortSelection) {
                ForEach(sorts) { sort in
                    Text(sort.title).tag(Optional(sort.value))
                }
            } label: {}
            .pickerStyle(.inline)
        } label: {
            LabeledContent {
                HStack(spacing: 6) {
                    if let pickedSort {
                        Text(pickedSort.title)
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .font(.body)
                .foregroundStyle(Color(.OnSurface.textSecondary))
            } label: {
                // The font on the whole label, so the icon takes the title's
                // size; the weight on the title only.
                Label {
                    Text("Sort by")
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .font(.body)
                .foregroundStyle(Color(.OnSurface.textPrimary))
            }
        }
    }

    /// The sort the search runs, as `ClientSearchOptions.isPicked` names it —
    /// the server's default while none is picked —; `nil` when none matches.
    private var pickedSort: ClientSort? {
        sorts.first(where: editor.draft.options.isPicked)
    }

    /// The bridge between the `Picker`, which speaks in row tags, and the
    /// draft's options, which keep a sort's value and its direction. A row is
    /// tagged with its sort's `value`, unique among the sorts
    /// (`@Attribute(.unique)`), so the tag finds the stored sort back.
    /// Reading ticks `pickedSort` — its value and its direction —, none,
    /// `nil`, when none matches; writing picks the chosen sort through
    /// `ClientSearchOptions.pick`, its value and its stored direction, in the
    /// draft: the list changes with "Show" only.
    private var sortSelection: Binding<String?> {
        Binding {
            pickedSort?.value
        } set: { value in
            guard let sort = sorts.first(where: { $0.value == value }) else { return }
            editor.draft.options.pick(sort)
        }
    }

    // MARK: - Filters

    /// One of the tenant's filters, on the screen's background rather than in
    /// a card, as the mockup draws it: no fill, the list's own hairline
    /// between two filters — none above the first nor under the last —, from
    /// one edge of the group to the other.
    ///
    /// A touch on a value lets go of it when it is picked, pushes the
    /// calendar for one that asks for a day, and picks it otherwise — a
    /// filter that takes one value lets go of the one it had
    /// (`ClientFilterDraft.toggle`).
    private func filterRow(for filter: ClientFilter) -> some View {
        ClientFilterGroup(filter: filter, draft: editor.draft) { value in
            if editor.draft.needsDay(for: value) {
                calendarRef = value.ref
            } else {
                editor.draft.toggle(value, of: filter)
            }
        }
        .listRowInsets(Self.filterRowInsets)
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
    }

    /// The calendar pushed for the value `ref`, titled with its filter, which
    /// picks the value once a day is confirmed. The closure keeps the ref, so
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

    // MARK: - Toolbar

    /// iOS's places for a sheet's bar (decision of 17/11, the mockup's too):
    /// what closes it on the leading edge, its other action on the trailing
    /// one.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            // The system's close button: its cross, its glass, "Close" for
            // VoiceOver. `DetailScreen` and `ComposerScreen` draw their
            // `xmark` by hand.
            Button(role: .close) {
                dismiss()
            }
            .barButtonStyle()
        }
        ToolbarItem(placement: .topBarTrailing) {
            clearButton
        }
    }

    /// Puts the server's default sort back and takes every filter off, with
    /// what the last sentence left; the field stays. In the draft: "Show"
    /// applies it.
    private var clearButton: some View {
        Button(String(localized: "Clear")) {
            editor.draft.clear()
        }
        .disabled(!editor.draft.canClear)
        .barButtonStyle()
    }

    // MARK: - Show

    /// "Show 42 clients" once the draft's clients are counted, "Show" alone
    /// while they are and when the count failed — active all the while: the
    /// total is a hint, not a gate. Writes the draft's sort and filters into
    /// the list's options, which starts its search over if they changed, and
    /// closes the sheet.
    ///
    /// The list's search then fails ("Search failed") on a value the tenant
    /// removed since the app's launch (409 `filters_changed`), until it is
    /// let go of or the app relaunched: too rare to be worth the code.
    private var showButton: some View {
        Button {
            options = editor.draft.options
            dismiss()
        } label: {
            Text(showLabel)
        }
        .bottomActionStyle()
    }

    /// "Show 42 clients" with the total, "Show" without it.
    private var showLabel: String {
        if let total = editor.total.value {
            String(localized: "Show \(total) clients")
        } else {
            String(localized: "Show")
        }
    }
}

// MARK: - Previews

#Preview(traits: .searchOptionsSampleData) {
    @Previewable @State var options = ClientSearchOptions()

    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientSortFilterSheet(options: $options)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
}
