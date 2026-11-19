//
//  ClientSortFilterView.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "Sort & filter" for the Clients tab's list, opened full screen by the
/// bar's button (`ClientsView`; decision of 18/11). From top to bottom: the
/// close button, the title and "Clear"; the sentence; "Sort by"; the groups
/// of filter pills
/// (`ClientFilterGroup`) — "Powered by Tolby" first, the filters a
/// description gave, when there are any, then the tenant's filters
/// (`ClientFilter`) in the server's order, a segment's pill with a dot in
/// its colours (`ClientSegment`) —; "Show N clients".
///
/// Everything picked goes into a draft (`ClientFilterDraft`, held by
/// `ClientFilterEditor`), made from the list's options once, in `init` —
/// `onAppear` would make it again on the way back from the calendar. Only
/// "Show" hands them back to the list, with their total when it is counted
/// (`onShow`), and closes the screen; the close button drops them — no swipe
/// down closes a full screen. "Clear" puts the server's default sort back
/// and takes the filters off, in the draft.
///
/// The sentence's arrow opens "Your description"
/// (`ClientFiltersDescriptionSheet`), which reads it on a draft of its own;
/// its "Apply" hands the filters Tolby understood back, the draft adds them
/// to its pills and empties the field (`ClientFilterDraft.apply`), and the
/// count starts over on its own.
struct ClientSortFilterView: View {
    /// What "Show" hands back to the list: the sort and the filters picked,
    /// and their total when it is counted — `nil` while a count is on its
    /// way, and after one that failed.
    private let onShow: (ClientSearchOptions, Int?) -> Void

    @Query(sort: \ClientSort.rank) private var sorts: [ClientSort]
    @Query(sort: \ClientFilter.rank) private var filters: [ClientFilter]
    /// The brand's segments, for the dots of the filter whose values they
    /// are (`segmentDot`).
    @Query(sort: \ClientSegment.rank) private var segments: [ClientSegment]
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @State private var editor: ClientFilterEditor
    /// Whether "Voice search" is open, from the sentence's microphone.
    @State private var isDictating = false
    /// Whether "Your description" is open, from the sentence's arrow: the
    /// sheet where the sentence is translated into filters.
    @State private var isTranslatingSentence = false
    /// The `ref` of the value the calendar is open for, while it is pushed —
    /// one calendar at a time, whatever the filter. Only the ref is kept: the
    /// draft finds the filter and the value by it once a day is confirmed
    /// (`ClientFilter.offering`).
    @State private var calendarRef: String?
    @FocusState private var isSentenceFocused: Bool
    /// The sentence's line: 22 pt, iOS's for `.body` and the mockup's, scaled
    /// like the text — what the pebble and the buttons sit on.
    @ScaledMetric(relativeTo: .body) private var sentenceLineHeight: CGFloat = 22
    /// A segment's dot in its pill: 10 pt, the mockup's, scaled like the
    /// pills' text.
    @ScaledMetric(relativeTo: .subheadline) private var segmentDotSize: CGFloat = 10

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
    /// The ring of a segment's dot, the mockup's.
    private static let segmentDotRing: CGFloat = 1.5

    /// `options`, the list's own, only seeds the draft: nothing reads them
    /// again, "Show" hands the draft's back.
    init(options: ClientSearchOptions, onShow: @escaping (ClientSearchOptions, Int?) -> Void) {
        self.onShow = onShow
        _editor = State(initialValue: ClientFilterEditor(options: options))
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
                // One section for every group, so the list draws its
                // hairline between two of them and none above the first. A
                // tenant without filters still shows Tolby's.
                if !filters.isEmpty || !editor.draft.filterItems.isEmpty {
                    Section {
                        if !editor.draft.filterItems.isEmpty {
                            tolbyRow
                        }
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
            // mockup draws it over this screen.
            .sheet(isPresented: $isDictating) {
                ClientVoiceSearchSheet { dictated in
                    editor.draft.text.append(dictation: dictated)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            // On the list and at half height, as "Voice search" above. The
            // sheet is handed the sentence alone and reads it on its own
            // draft; "Apply" hands back what Tolby understood, which changes
            // the draft's filters — and so starts the count below over.
            .sheet(isPresented: $isTranslatingSentence) {
                ClientFiltersDescriptionSheet(sentence: editor.draft.text) { understood in
                    editor.draft.apply(understood)
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
    ///   was, and the arrow, which opens "Your description"
    ///   (`ClientFiltersDescriptionSheet`) on the sentence.
    ///
    /// The sentence is read for its filters there, on that sheet's own draft
    /// (`ClientFilterEditor.readSentence`), never here. Its "Apply" empties
    /// the field — the microphone is back — and adds what Tolby understood to
    /// the pills of "Powered by Tolby" (`ClientFilterDraft.apply`); closed
    /// otherwise, it leaves the sentence in the field.
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
                    // The caret out of the field first: the keyboard would
                    // cover a sheet at half height.
                    isSentenceFocused = false
                    isTranslatingSentence = true
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

    /// A group of filter pills as a row of the list, on the screen's
    /// background rather than in a card, as the mockup draws it: no fill, the
    /// list's own hairline between two groups — none above the first nor
    /// under the last —, from one edge of the group to the other.
    private func groupRow(_ group: some View) -> some View {
        group
            .listRowInsets(Self.filterRowInsets)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color(.OnSurface.borderSubtle))
    }

    /// "Powered by Tolby": the filters a description gave
    /// (`ClientFilterDraft.filterItems`), the first of the groups, as the
    /// mockup draws it (`C-Filtres-Applique-Noir`) — each a pill in ink, as
    /// one chosen, with its cross, under the server's label, already in the
    /// associate's language. No count beside the title, no violet: they are
    /// filters like the others, once applied. The row leaves with its last
    /// pill.
    private var tolbyRow: some View {
        groupRow(
            ClientFilterGroup(title: String(localized: "Powered by Tolby")) {
                ForEach(editor.draft.filterItems) { item in
                    // One of Tolby's filters has no "not chosen" to go back
                    // to: letting go of it is taking it off. So a touch on
                    // the pill removes it as its cross does — the mockup's
                    // whole pill is its remove button.
                    Pill(
                        isSelected: true,
                        isRemovable: true,
                        accessibilityLabel: item.label,
                        onToggle: { _ in editor.draft.remove(item) },
                        onRemove: { editor.draft.remove(item) }
                    ) {
                        Text(verbatim: item.label)
                    }
                }
            }
        )
    }

    /// One of the tenant's filters: its title, how many of its values are
    /// picked, and its values, each a pill (`valuePill`).
    private func filterRow(for filter: ClientFilter) -> some View {
        groupRow(
            ClientFilterGroup(
                title: String(localized: filter.title),
                pickedCount: editor.draft.pickedCount(in: filter)
            ) {
                ForEach(filter.values, id: \.ref) { value in
                    valuePill(value, of: filter)
                }
            }
        )
    }

    /// A value's pill. What it shows depends on where its filter's values
    /// come from (`ClientFilter.valueField`), each kind in its own function:
    /// the brand's segments (`segmentValueContent`), any other filter
    /// (`standardValueContent`). A new kind of filter adds its case here.
    ///
    /// A touch lets go of the value when it is picked, pushes the calendar
    /// for one that asks for a day, and picks it otherwise — a filter that
    /// takes one value lets go of the one it had (`ClientFilterDraft.toggle`).
    ///
    /// Not in the pill yet (decision of 17/11): a status's point.
    private func valuePill(_ value: ClientFilterValue, of filter: ClientFilter) -> some View {
        let isPicked = editor.draft.isPicked(value)
        let day = editor.draft.day(pickedFor: value)?.formatted(date: .abbreviated, time: .omitted)
        return Pill(
            isSelected: isPicked,
            accessibilityLabel: [value.title, day].compactMap(\.self).joined(separator: ", ")
        ) { _ in
            if editor.draft.needsDay(for: value) {
                calendarRef = value.ref
            } else {
                editor.draft.toggle(value, of: filter)
            }
        } content: {
            // `nil` rather than `default`: a kind added to `ValueField` must
            // say here what its pills show.
            switch filter.valueField {
            case .segment: segmentValueContent(value, isPicked: isPicked)
            case nil: standardValueContent(value, day: day)
            }
        }
    }

    /// A value's content as any filter shows it: its name, then the day
    /// picked for it, if any — "Since a date" —, in the pill's secondary
    /// level.
    private func standardValueContent(_ value: ClientFilterValue, day: String?) -> some View {
        // 7 pt between the name and its day, the mockup's gap in a pill.
        HStack(spacing: 7) {
            Text(value.title)
            if let day {
                Text(day)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A segment's content, in the filter whose values are the brand's
    /// segments: its dot, then its name. A value's `label` is its segment's
    /// code; no dot for a segment the brand does not list or has not
    /// coloured (`ClientSegment.dotColors`), as it has no tag in the list.
    private func segmentValueContent(_ value: ClientFilterValue, isPicked: Bool) -> some View {
        // 7 pt between the dot and the name, the mockup's gap in a pill.
        HStack(spacing: 7) {
            if let colors = ClientSegment.named(value.label, in: segments)?.dotColors {
                segmentDot(colors, isPicked: isPicked)
            }
            Text(value.title)
        }
    }

    /// A segment's dot, before its name in its pill, in the colours its
    /// segment gives it (`ClientSegment.dotColors`, decision of 18/11): the
    /// tag's background made stronger, ringed inside with a soft edge of its
    /// text colour, so a pale segment still shows without a dark circle. On
    /// a picked pill, the ink, the ring is white at 75 % and outside the dot
    /// instead, as the mockup draws it (`C-Filtres`), the name staying where
    /// it is.
    private func segmentDot(_ colors: (fill: Color, ring: Color), isPicked: Bool) -> some View {
        Circle()
            .fill(colors.fill)
            .frame(width: segmentDotSize, height: segmentDotSize)
            .overlay {
                if isPicked {
                    Circle()
                        .strokeBorder(Color(.Base.paper).opacity(0.75), lineWidth: Self.segmentDotRing)
                        .padding(-Self.segmentDotRing)
                } else {
                    Circle()
                        .strokeBorder(colors.ring, lineWidth: Self.segmentDotRing)
                }
            }
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

    /// iOS's places for a modal screen's bar (decision of 17/11, the mockup's
    /// too):
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

    /// Puts the server's default sort back and takes every filter off, the
    /// values picked and Tolby's pills; the field stays. In the draft: "Show"
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
    /// until the first count comes back and when a count failed — active all
    /// the while: the total is a hint, not a gate. The last total stays while
    /// a newer one is counted, faded, then its digits roll to the new one
    /// (decision of 18/11); VoiceOver reads that last total meanwhile, the
    /// fading being for the eye only. Hands the draft's sort and filters back
    /// to the list (`onShow`), which starts its search over if they changed,
    /// with their total for its subtitle, and closes the screen.
    ///
    /// The list's search then fails ("Search failed") on a value the tenant
    /// removed since the app's launch (409 `filters_changed`), until it is
    /// let go of or the app relaunched: too rare to be worth the code.
    private var showButton: some View {
        Button {
            // The total only if it is the draft's: the last one, kept while
            // a newer is counted, would be another filter's.
            onShow(editor.draft.options, editor.isCounting ? nil : editor.total)
            dismiss()
        } label: {
            Text(showLabel)
                // The digits roll from the last total to the new one.
                .contentTransition(.numericText(value: Double(editor.total ?? 0)))
                .animation(.default, value: editor.total)
        }
        .bottomActionStyle()
    }

    /// "Show 42 clients" with the last total counted, "Show" without one. The
    /// number alone fades while a newer count is on its way: fading the whole
    /// label would read as a disabled button. The catalog's own string, its
    /// plural included; the number's range is the one Foundation marks as the
    /// value put in. Its colour is the white `bottomActionStyle()` gives the
    /// label on the ink, at half: to change with it.
    private var showLabel: AttributedString {
        guard let total = editor.total else { return AttributedString(localized: "Show") }
        var label = AttributedString(localized: "Show \(total) clients", options: .applyReplacementIndexAttribute)
        if editor.isCounting {
            for run in label.runs where run.replacementIndex != nil {
                label[run.range].foregroundColor = Color(.Base.paper).opacity(0.5)
            }
        }
        return label
    }
}

// MARK: - Previews

#Preview("With Tolby's filters", traits: .searchOptionsSampleData) {
    // The list's options as "Show" left them: two filters a description gave.
    // Their conditions are never read here.
    let options = ClientSearchOptions(filters: [
        .filter(ClientFilterItem(label: "Segment · VIC", condition: .object(["field": .string("client.segment")]))),
        .filter(ClientFilterItem(label: "Opted in · WhatsApp", condition: .object(["field": .string("client.optIn")]))),
    ])

    Color.clear
        .fullScreenCover(isPresented: .constant(true)) {
            ClientSortFilterView(options: options) { _, _ in }
        }
}

#Preview(traits: .searchOptionsSampleData) {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) {
            ClientSortFilterView(options: ClientSearchOptions()) { _, _ in }
        }
}
