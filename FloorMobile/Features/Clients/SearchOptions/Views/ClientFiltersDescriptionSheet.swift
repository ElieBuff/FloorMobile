//
//  ClientFiltersDescriptionSheet.swift
//  FloorMobile
//

import SwiftUI

/// "Your description", opened by the arrow of "Sort & filter"'s sentence
/// (`ClientSortFilterView`): the clients wanted, in the associate's own
/// words, read back while Tolby translates them into filters. Under the title
/// and the close button, the sentence in quotes, on three lines at most — a
/// longer one is cut with an ellipsis —, then Tolby's card
/// (`ClientFiltersProcessingCard`, below), and "Apply" at the bottom.
///
/// The sentence is read as the sheet opens (`ClientFilterEditor.readSentence`,
/// `client/text-filters`), on a draft made of the sentence alone, held by an
/// editor of the sheet's own: nothing of "Sort & filter"'s draft comes in, so
/// the card only ever lists this sentence's filters. The card says where the
/// reading stands: "Tolby is working it out…" while the answer is on its way,
/// what failed and "Try again" when it did, and, once the answer is in, what
/// Tolby understood and what it did not (mockup `C-Voix-Compris`). Closing
/// the sheet — the close button, a swipe down — cancels the reading, and
/// hands nothing back.
///
/// "Apply", greyed until the answer is in, hands the filters Tolby understood
/// back (`onApply`) and closes; "Sort & filter" adds them to its draft and
/// empties its field (`ClientFilterDraft.apply`). The sentence is never
/// greyed nor underlined where Tolby did not understand it, as the mockup
/// does (decision of 18/11).
///
/// Built as "Voice search" is (`ClientVoiceSearchSheet`): the same bar, the
/// same plain background, the same action at the bottom, at half height. The
/// sentence and the card scroll when they outgrow it — three lines of
/// sentence, two of filters and "Not understood" do —, and only then.
struct ClientFiltersDescriptionSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    /// The filters Tolby understood, once, on "Apply" — none when it
    /// understood nothing.
    private let onApply: ([ClientFilterItem]) -> Void

    /// The draft the sentence is read on — made of the sentence alone —, and
    /// its reading.
    @State private var editor: ClientFilterEditor
    /// How many times the sentence was asked to be read again: "Try again"
    /// adds one, which starts the sheet's task over.
    @State private var attempt = 0
    /// The sentence's line: 28 pt, iOS's for `.title2`, scaled like the text —
    /// set rather than left to the font, whose own line grows with the
    /// device's languages (`AppFont`).
    @ScaledMetric(relativeTo: .title2) private var lineHeight: CGFloat = 28

    /// On `sentence`, as "Sort & filter"'s field holds it when the arrow is
    /// touched, and on nothing else of its draft: with its pills, the card
    /// would list an earlier description's filters as understood from this
    /// one, before the sentence is even read.
    init(sentence: String, onApply: @escaping ([ClientFilterItem]) -> Void) {
        self.init(draft: ClientFilterDraft(text: sentence), onApply: onApply)
    }

    /// On a draft as it stands: the previews', which show a sentence already
    /// read. `fileprivate`, a `#Preview` being a type of its own in this
    /// file.
    fileprivate init(draft: ClientFilterDraft, onApply: @escaping ([ClientFilterItem]) -> Void) {
        self.onApply = onApply
        _editor = State(initialValue: ClientFilterEditor(draft: draft))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    sentence
                    ClientFiltersProcessingCard(draft: editor.draft) {
                        attempt += 1
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaBar(edge: .bottom) {
                applyButton
            }
            .sheetBackground()
            .navigationTitle(Text("Your description"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // The system's close button, as in "Voice search".
                    Button(role: .close) {
                        dismiss()
                    }
                    .barButtonStyle()
                }
            }
        }
        // Reads the sentence as the sheet opens, and again on "Try again";
        // closing the sheet cancels it. Until its first pass — a frame, while
        // the sheet comes up — nothing is sent yet, and no card shows.
        .task(id: attempt) {
            await editor.readSentence(session: session, services: services)
        }
    }

    // MARK: - Sentence

    /// The sentence in quotes, as the mockup writes it, 12 pt under the bar
    /// and 20 from the edges. In `.title2` Medium — 22 pt, iOS's nearest to
    /// the mockup's 24 (decision of 17/11) —, without the mockup's tracking,
    /// which goes with its size. `verbatim`: what the associate wrote is not a
    /// string to translate. VoiceOver reads it whole, cut or not.
    ///
    /// Shown as the field holds it, where it is sent trimmed: spaces or a line
    /// break left around it show between the quotes. A field of spaces alone
    /// opens empty quotes, is not sent, and leaves "Apply" greyed: the close
    /// button is the way out.
    private var sentence: some View {
        Text(verbatim: "“\(editor.draft.text)”")
            .font(.title2.weight(.medium))
            .lineHeight(.exact(points: lineHeight))
            .foregroundStyle(Color(.OnSurface.textPrimary))
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
    }

    // MARK: - Apply

    /// Hands the filters Tolby understood back and closes — none when it
    /// understood nothing: what becomes of them, and of the sentence, is the
    /// caller's draft's rule (`ClientFilterDraft.apply`), not this button's.
    ///
    /// Active on an answer only (`ClientFilterDraft.hasAnswer`): greyed
    /// while Tolby works and when the reading failed, as the mockup draws it,
    /// and before the sentence is sent. Every answer of the server's carries
    /// filters or parts not understood (`ClientFilterItems`).
    private var applyButton: some View {
        Button(String(localized: "Apply")) {
            onApply(editor.draft.filterItems)
            dismiss()
        }
        .disabled(!editor.draft.hasAnswer)
        .bottomActionStyle()
    }
}

// MARK: - Processing card

/// Tolby's card in "Your description", where the processing of the sentence
/// stands, read off the sheet's draft: working while the sentence waits for
/// its answer, what failed if it did, then what the answer says — the
/// filters Tolby understood, and the parts of the sentence it did not, each
/// only when there is any; no card for an answer with neither
/// (`ClientFilterDraft.hasAnswer`). Drawn as the mockups draw it
/// (`C-Voix-Charge`, `C-Voix-Compris`), 16 pt under the sentence, at the
/// screen's inset.
///
/// The sheet's own, in its file (the user's decision of 17/11): it serves no
/// other screen, so neither a component of the feature nor of the design
/// system. A type rather than views of the sheet, so the card keeps to
/// itself what only it needs — its sizes, and what stops its motion.
private struct ClientFiltersProcessingCard: View {
    /// The draft the sentence is read on: the card shows where its sentence
    /// stands (`hasPendingText`, `failure`, `hasAnswer`).
    let draft: ClientFilterDraft
    /// "Try again": reads the sentence once more.
    let retry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// Whether what the answer says has come on screen: set once, as it
    /// appears. The tags' capsules and "Not understood" come in on it, from
    /// the same instant (decision of 18/11, where the mockup holds "Not
    /// understood" back). Once for each time the sheet opens: an answer that
    /// comes after a failure and "Try again" finds it set, and shows its
    /// capsules and "Not understood" at rest — too rare to be worth the code.
    @State private var hasArrived = false

    /// The card, the mockup's: its corners, and the margins inside it.
    private static let radius: CGFloat = 20
    private static let insets = EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16)
    /// The card's titles, the mockup's 12 pt semibold: "Tolby is working it
    /// out…", "Tolby understood", "Not understood".
    private static let titleFont: Font = .caption.weight(.semibold)
    /// The tags, the mockup's: the room between two of a line and between two
    /// lines, and how long after the one before a filter understood comes in.
    private static let tagSpacing: CGFloat = 8
    private static let tagStagger: TimeInterval = 0.22
    /// A filter's capsule as it comes in, the mockup's (`paCap`): from this
    /// scale to its own, and into view, in `capsuleDuration`.
    private static let capsuleStartScale = 0.9
    private static let capsuleDuration: TimeInterval = 0.28
    /// "Not understood" fading in, the mockup's (`paFade`).
    private static let fadeDuration: TimeInterval = 0.4
    /// The dashes of a part not understood's outline, and the gaps between
    /// them: what a browser draws for the mockup's 1 pt dashed border.
    private static let notUnderstoodDash: [CGFloat] = [3, 3]
    /// The skeleton, the mockup's: two pills to come — as high as the tags
    /// that take their place (`TagSize.large`), to keep in step with it —,
    /// then a line — its height, and its share of the card's width.
    private static let skeletonPillWidths: [CGFloat] = [112, 158]
    private static let skeletonPillHeight: CGFloat = 34
    private static let skeletonLineHeight: CGFloat = 8
    private static let skeletonLineShare: CGFloat = 0.58
    /// The skeleton's reflection, the mockup's: it crosses each shape every
    /// `reflectionPeriod`, a shape `reflectionDelay` after the one before.
    private static let reflectionPeriod: TimeInterval = 1.2
    private static let reflectionDelay: TimeInterval = 0.15
    /// The title's dots, the mockup's: each lights up every `dotsPeriod`,
    /// `dotsDelay` after the one before.
    private static let dotsPeriod: TimeInterval = 1.2
    private static let dotsDelay: TimeInterval = 0.2

    var body: some View {
        if draft.hasPendingText {
            card { working }
        } else if let failure = draft.failure {
            card { failed(failure) }
        } else if draft.hasAnswer {
            card { understood }
        }
    }

    /// The card around `content`, in the app's card white
    /// (`OnCanvas.surface`) — the mockup's own is fainter. Its place in the
    /// sheet is set here rather than by the sheet: with no card to show,
    /// nothing must take that room.
    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Self.insets)
            .cardStyle(radius: Self.radius)
            .padding(.horizontal, AppSpacing.screenInset)
            .padding(.top, 16)
    }

    /// The card's title: Tolby's pebble, then `words` — "Tolby is working it
    /// out…", "Tolby understood" —, which bring their own colour, in the
    /// titles' font.
    private func title(@ViewBuilder _ words: () -> some View) -> some View {
        HStack(spacing: 8) {
            // 12 pt drawn in a box of 16, the mockup's.
            IntelligencePebble(size: 12)
                .frame(width: 16, height: 16)
            words()
                .font(Self.titleFont)
        }
    }

    // MARK: - Working

    /// "Tolby is working it out…": the pebble, the words in Tolby's violet and
    /// their three dots lighting up in turn, then the skeleton of what is to
    /// come. One element for VoiceOver, which reads the words.
    private var working: some View {
        VStack(alignment: .leading, spacing: 12) {
            title {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isMotionPaused)) { context in
                    Text(workingWords(at: context.date))
                }
            }
            skeleton
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Tolby is working it out"))
    }

    /// The words and their three dots at `date`, in one text, as the mockup
    /// writes them: three full stops in the words' own font, so they sit on
    /// the baseline, as far apart as the font sets them. Not the `ellipsis`
    /// symbol a language's download wears (`LanguageDownloadView`): its dots
    /// sit at mid-height, closer together. Each dot in its own opacity
    /// (`dotOpacity`); at rest — Reduce Motion, the background — all three
    /// are lit.
    private func workingWords(at date: Date) -> AttributedString {
        var words = AttributedString(String(localized: "Tolby is working it out"))
        words.foregroundColor = Color(.Pebble.deep)
        for index in 0..<3 {
            var dot = AttributedString(".")
            dot.foregroundColor = Color(.Pebble.deep)
                .opacity(isMotionPaused ? 1 : Self.dotOpacity(index, at: date))
            words += dot
        }
        return words
    }

    /// How lit the dot `index` is at `date`, the mockup's loop: faint for the
    /// first fifth, up to full by the half, back to faint by the end, eased
    /// in and out — each dot `dotsDelay` after the one before.
    private static func dotOpacity(_ index: Int, at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate - dotsDelay * Double(index)
        let progress = elapsed.truncatingRemainder(dividingBy: dotsPeriod) / dotsPeriod
        switch progress {
        case ..<0.2: return 0.2
        case ..<0.5: return 0.2 + 0.8 * eased((progress - 0.2) / 0.3)
        default: return 1 - 0.8 * eased((progress - 0.5) / 0.5)
        }
    }

    /// `linear`, from 0 to 1, eased in and out.
    private static func eased(_ linear: Double) -> Double {
        (1 - cos(linear * .pi)) / 2
    }

    /// The skeleton, at the mockup's sizes: two pills to come, then a line,
    /// each in a pale violet its own reflection crosses (`skeletonFill`), one
    /// shape after the other. Not `SkeletonLines`, the app's grey bars at
    /// rest: these stand for Tolby's pills, in its violet.
    ///
    /// Read off absolute time and stopped — the shapes then stay pale — under
    /// Reduce Motion and in the background, as the app's other ambient
    /// motions (`SpecularSweep`).
    private var skeleton: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isMotionPaused)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(Array(Self.skeletonPillWidths.enumerated()), id: \.offset) { index, width in
                        Capsule()
                            .fill(skeletonFill(ofShape: index, at: context.date))
                            .frame(width: width, height: Self.skeletonPillHeight)
                    }
                }
                GeometryReader { proxy in
                    Capsule()
                        .fill(skeletonFill(ofShape: Self.skeletonPillWidths.count, at: context.date))
                        .frame(width: proxy.size.width * Self.skeletonLineShare)
                }
                .frame(height: Self.skeletonLineHeight)
            }
        }
    }

    /// Whether the card's motions rest — the dots and the reflection: when
    /// motion would be unwelcome (Reduce Motion) or unseen (app in the
    /// background).
    private var isMotionPaused: Bool {
        reduceMotion || scenePhase != .active
    }

    /// What fills the skeleton's shape `index` at `date`: the design system's
    /// reflection (`IntelligenceReveal.reflection`, which a text Tolby wrote
    /// comes in under too), crossing the shape once every `reflectionPeriod`
    /// — its geometry leaves the shape pale for almost half the loop. At
    /// rest, it stays before the shape's edge: pale all over.
    ///
    /// `Pebble.mid` at 12 % and at 40 %: on a light ground, what the mockup's
    /// two violets give (`#5B3DF5` at 12 %, `#8E78FA` at 50 %), without a
    /// colour of their own. Decision of 17/11, on screen: one reflection as
    /// wide as the whole skeleton, laid over the pale, lit each pill whole,
    /// and far more violet than the mockup.
    private func skeletonFill(ofShape index: Int, at date: Date) -> LinearGradient {
        var progress = 0.0
        if !isMotionPaused {
            let elapsed = date.timeIntervalSinceReferenceDate - Self.reflectionDelay * Double(index)
            progress = elapsed.truncatingRemainder(dividingBy: Self.reflectionPeriod) / Self.reflectionPeriod
        }
        return IntelligenceReveal.reflection(at: progress, pale: 0.12, bright: 0.4)
    }

    // MARK: - Understood

    /// What the answer says, each part only when there is any: "Tolby
    /// understood" over the filters the sentence describes, a hairline when
    /// both parts are there, "Not understood" over the parts no filter
    /// covers. At the mockup's distances: 10 pt under the first title, 8
    /// under the second, 12 around the hairline.
    ///
    /// Tags, not pills: they only show — taking a filter off is "Sort &
    /// filter"'s. A tag stays on one line, cut with an ellipsis past the
    /// card's width — a long part not understood; VoiceOver reads it whole.
    private var understood: some View {
        let items = draft.filterItems
        let parts = draft.notUnderstood
        return VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    title {
                        Text("Tolby understood")
                            .foregroundStyle(Color(.Pebble.deep))
                            .accessibilityAddTraits(.isHeader)
                    }
                    FlowLayout(spacing: Self.tagSpacing, lineSpacing: Self.tagSpacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            understoodTag(item.label, delay: Self.tagStagger * Double(index))
                        }
                    }
                }
            }
            if !items.isEmpty, !parts.isEmpty {
                CardDivider(inset: 0)
            }
            if !parts.isEmpty {
                notUnderstood(parts)
            }
        }
        .onAppear { hasArrived = true }
    }

    /// Whether what the answer says shows as it rests: once it has arrived,
    /// and from the start under Reduce Motion, where nothing comes in.
    private var isSettled: Bool {
        hasArrived || reduceMotion
    }

    /// A filter Tolby understood, as the mockup brings it in, `delay` after
    /// the answer arrives: its capsule grows into view (`paCap`), and its
    /// label — the server's words, already in the associate's language —
    /// comes in as what the intelligence writes (`.intelligenceReveal`), on
    /// the same delay.
    private func understoodTag(_ label: String, delay: TimeInterval) -> some View {
        Text(verbatim: label)
            .intelligenceReveal(delay: delay)
            .tagStyle(.large, background: Color(.OnSurface.surfaceFaint), foreground: Color(.Pebble.deep))
            .scaleEffect(isSettled ? 1 : Self.capsuleStartScale)
            .opacity(isSettled ? 1 : 0)
            .animation(
                .timingCurve(0.2, 0.8, 0.2, 1, duration: Self.capsuleDuration).delay(delay),
                value: hasArrived
            )
    }

    /// "Not understood" over the parts of the sentence no filter covers, each
    /// in quotes — the associate's own words, not a string to translate — in
    /// a tag with no fill and a dashed outline, in the mockup's brown. Fading
    /// in as the answer arrives, with the first filter understood.
    ///
    /// By their place in the answer: two parts may read alike.
    private func notUnderstood(_ parts: [String]) -> some View {
        let brown = Color(.Accent.notUnderstood)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Not understood")
                .font(Self.titleFont)
                .foregroundStyle(brown)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Self.tagSpacing, lineSpacing: Self.tagSpacing) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Text(verbatim: "“\(part)”")
                        .tagStyle(
                            .large,
                            foreground: brown,
                            border: AppBorder(color: brown.opacity(0.55), dash: Self.notUnderstoodDash)
                        )
                }
            }
        }
        .opacity(isSettled ? 1 : 0)
        // CSS's `ease`, the mockup's curve.
        .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: Self.fadeDuration), value: hasArrived)
    }

    // MARK: - Failure

    /// What failed, and "Try again". Without the pebble and "Tolby is working
    /// it out…": Tolby no longer is. The message is the editor's
    /// (`ClientFilterEditor.readSentence`). Not `EmptySectionCard`, the app's
    /// "Try again" banner: its white text is made for the ambient background,
    /// not for a sheet's. Nor `LoadFailureView`: it stands in for a whole
    /// screen that failed to load, with a title and the error's own message,
    /// where this is one card under the sentence, saying the editor's words.
    /// Laid out here: the mockups draw no failure.
    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color(.OnSurface.textPrimary))
            Button(String(localized: "Try again"), action: retry)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color(.Base.ink))
        }
    }
}

// MARK: - Previews

// No server answers the previews' session: a sentence to read shows what
// failed. A draft already read — `lastFetched` is its sentence, so nothing is
// sent — shows what Tolby understood.

#Preview("Understood and not understood", traits: .searchOptionsSampleData) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFiltersDescriptionSheet(
                draft: .previewRead(understood: ["Segment · VIC", "Opted in · WhatsApp"], notUnderstood: ["who like red"])
            ) { _ in }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Understood only", traits: .searchOptionsSampleData) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFiltersDescriptionSheet(
                draft: .previewRead(
                    understood: [
                        "Segment · VIC", "Opted in · WhatsApp", "Bought in the last 3 months",
                        "More than €10,000 spent in 2026", "Lives in Paris",
                    ],
                    notUnderstood: []
                )
            ) { _ in }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Not understood only", traits: .searchOptionsSampleData) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFiltersDescriptionSheet(
                draft: .previewRead(understood: [], notUnderstood: ["VIC clients on WhatsApp who like red"])
            ) { _ in }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

private extension ClientFilterDraft {
    /// A draft whose sentence was read already, for the previews: its filters
    /// by their labels, and the parts no filter covers. The conditions are
    /// never read here.
    static func previewRead(understood: [String], notUnderstood: [String]) -> ClientFilterDraft {
        let sentence = "VIC clients on WhatsApp who like red"
        return ClientFilterDraft(
            options: ClientSearchOptions(
                filters: understood.map { .filter(ClientFilterItem(label: $0, condition: .null)) }
            ),
            text: sentence,
            lastFetched: sentence,
            notUnderstood: notUnderstood
        )
    }
}

#Preview("Short", traits: .searchOptionsSampleData) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFiltersDescriptionSheet(sentence: "VIC clients on WhatsApp who like red") { _ in }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}

#Preview("Longer than three lines", traits: .searchOptionsSampleData) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ClientFiltersDescriptionSheet(
                sentence: "VIC clients on WhatsApp who like red, bought a trench coat in the last year, live "
                    + "locally and have not come to the store since the spring collection was shown"
            ) { _ in }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}
