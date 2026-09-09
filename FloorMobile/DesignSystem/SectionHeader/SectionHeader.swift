//
//  SectionHeader.swift
//  FloorMobile
//

import SwiftUI

/// The title row of a content section: a title on the left, and optionally
/// something on the right — a tappable text link ("View all"), a custom
/// control (e.g. a segmented picker), or nothing at all.
///
/// Text parameters are plain `String`s: localization is the call site's
/// responsibility, via `String(localized:)` (design-system convention).
///
/// Three ways to use it (examples from the Home screen):
///
/// ```swift
/// // Title only, nothing on the right.
/// SectionHeader(title: "Some section")
///
/// // Title + a tappable text link.
/// SectionHeader(title: "Next appointment", actionLabel: "View agenda") {
///     openAgenda()
/// }
///
/// // Title + arbitrary trailing content.
/// SectionHeader(title: "Recently viewed") {
///     Picker("", selection: $recentTab) {
///         Text("Clients").tag(RecentTab.clients)
///         Text("Produits").tag(RecentTab.products)
///     }
///     .pickerStyle(.segmented)
///     .fixedSize()
/// }
/// ```
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color(.textPrimary))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

extension SectionHeader where Trailing == Button<Text> {
    /// A title with a tappable text link on the right, e.g. "View all" or
    /// "View agenda".
    init(title: String, actionLabel: String, action: @escaping () -> Void) {
        self.title = title
        self.trailing = {
            Button(action: action) {
                Text(actionLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
            }
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    /// A title with nothing on the right.
    init(title: String) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

// MARK: - Previews

#Preview("Title only") {
    SectionHeader(title: "Some section")
        .padding()
        .background(Color.black)
}

#Preview("Title + link") {
    VStack(alignment: .leading, spacing: 16) {
        SectionHeader(title: "AI recommendations", actionLabel: "View all") {}
        SectionHeader(title: "Next appointment", actionLabel: "View agenda") {}
        SectionHeader(title: "Today's tasks", actionLabel: "View agenda") {}
    }
    .padding()
    .background(Color.black)
}

#Preview("Title + custom trailing content") {
    SectionHeader(title: "Recently viewed") {
        Picker("", selection: .constant(0)) {
            Text("Clients").tag(0)
            Text("Produits").tag(1)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
    .padding()
    .background(Color.black)
}
