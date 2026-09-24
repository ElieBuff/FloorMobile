//
//  DetailStackedRow.swift
//  FloorMobile
//

import SwiftUI

/// A row whose content sits *under* its label rather than opposite it.
///
/// For the two things that cannot live in the right-hand half of a row: the
/// record's own name, which is the biggest text on the screen, and a note,
/// which is a paragraph. Both need the full width, so the label steps up a
/// line and gets out of the way.
///
/// The label is a `FieldLabel` in every case — the same grey the rows beside it
/// use, so a stacked row still reads as one of them.
///
/// ```swift
/// DetailStackedRow(label: task.reason.displayLabel, text: task.title, emphasis: .title)
/// DetailStackedRow(label: String(localized: "Note"), text: note)
/// ```
///
/// The generic form takes anything, for content a `Text` cannot express:
///
/// ```swift
/// DetailStackedRow(label: String(localized: "Status")) {
///     TaskStatusPicker(selection: $status)
/// }
/// ```
struct DetailStackedRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        // 3, the gap `FormTitleRow` puts between the same pair. The title of a
        // task is read here and edited one tap away; a different gap on each
        // screen makes it jump on the way.
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(label)

            // Both frames are load-bearing. Without them the stack takes the
            // width of its widest child and centres itself in the row, which
            // reads as a paragraph floating in the middle of the card.
            content()
                .foregroundStyle(Color(.OnSurface.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DetailStackedRow where Content == Text {
    /// The two treatments a text gets here, named rather than spelled at each
    /// call — otherwise the fourth stacked row stops matching the other three.
    enum Emphasis {
        /// The record's own name, under the category it belongs to.
        case title
        /// A value that reads in sentences.
        case body

        var font: Font {
            switch self {
            case .title: .title3
            case .body: .body
            }
        }
    }

    init(label: String, text: String, emphasis: Emphasis = .body) {
        self.init(label: label) { Text(text).font(emphasis.font) }
    }
}

// MARK: - Previews

#Preview("Title and note") {
    NavigationStack {
        List {
            Section {
                DetailStackedRow(
                    label: "Follow-up",
                    text: "Call about the Solène order, and the belt she asked to see",
                    emphasis: .title
                )
                .listRowInsets(.cardRow)
            }

            Section {
                DetailStackedRow(
                    label: "Note",
                    text: """
                        She was torn between the 38 and the 40. Have both sizes ready in the \
                        fitting room — and pull the matching belt in tan.
                        """
                )
                .listRowInsets(.cardRow)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .listRowBackground(Color(.OnCanvas.surface))
        .scrollContentBackground(.hidden)
        .ambientBackground()
        .navigationTitle(Text(verbatim: "Task"))
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(Color(.Base.ink))
}
