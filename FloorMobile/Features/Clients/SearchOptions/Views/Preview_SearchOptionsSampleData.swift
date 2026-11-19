//
//  Preview_SearchOptionsSampleData.swift
//  FloorMobile
//

import SwiftData
import SwiftUI

/// "My Clients"' catalogue as `GET setup` serves it in dev — its sorts, the
/// filters the dev seed writes, and the brand's segments, whose colours the
/// Tier's pills take for their dots — in an in-memory store, for the previews
/// that open "Sort & filter": `#Preview(traits: .searchOptionsSampleData)`.
///
/// A `PreviewModifier`, so the preview system builds the store once and shares
/// it across the previews that apply the trait; none of them writes to it. The
/// filters mirror `seed-client-filters.ts` (FloorPlatform's console API): the
/// Tier with the segments its header gives as an example, Created and Last
/// purchase with their four values.
/// The previews that apply it also get the session and the services "Sort &
/// filter" reads for its total — the previews' own, which no server answers:
/// "Show" stays alone. Not under `#if DEBUG`: a `#Preview` compiles in Release
/// builds too.
struct SearchOptionsSampleData: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        let container = try ModelContainer(
            for: ClientSort.self, ClientFilter.self, ClientSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let sorts: [(String, String)] = [
            ("name", "asc"), ("lastPurchase", "desc"), ("spent12M", "desc"),
            ("spentLifetime", "desc"), ("createdDate", "desc"), ("contactedByMe", "desc"),
        ]
        for (rank, (value, direction)) in sorts.enumerated() {
            container.mainContext.insert(ClientSort(
                value: value, labelKey: "client.sort.\(value)", directionRaw: direction,
                isDefault: rank == 0, rank: rank
            ))
        }
        // The dev tenant's segments, as its `GET setup` serves them: the
        // Tier's "Repeater" is not one of them, and shows a pill without a dot.
        let coloured: [(code: String, background: String, text: String)] = [
            ("One Timer", "#1454601A", "#1D5560"), ("Connoisseur", "#1454600D", "#2A5A63"),
            ("VIP", "#1454603D", "#ffffff"), ("VIC", "#14545F", "#ffffff"),
        ]
        for (rank, segment) in coloured.enumerated() {
            container.mainContext.insert(ClientSegment(
                code: segment.code, backgroundColorHex: segment.background, textColorHex: segment.text, rank: rank
            ))
        }
        let segments: [String] = ["VIC", "VIP", "Repeater", "One Timer"]
        let tier = segments.map {
            ClientFilterValue(ref: "tier-\($0)", labelKey: nil, label: $0, parameters: [])
        }
        let filters = [
            ClientFilter(
                id: "tier", titleKey: "client.filter.tier", selectionRaw: "MULTIPLE",
                valueFieldRaw: "client.segment", rank: 0, values: tier
            ),
            ClientFilter(
                id: "created", titleKey: "client.filter.created", selectionRaw: "SINGLE", rank: 1,
                values: datedValues("created")
            ),
            ClientFilter(
                id: "last_purchase", titleKey: "client.filter.lastPurchase", selectionRaw: "SINGLE", rank: 2,
                values: datedValues("last_purchase")
            ),
        ]
        for filter in filters {
            container.mainContext.insert(filter)
        }
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content
            .modelContainer(context)
            .environment(AppSession(auth: .preview, api: .preview))
            .environment(AppServices(container: context))
    }

    /// A date filter's values, as the seed writes them: the last 3, 6 and 12
    /// months, then "since a day", the date the associate picks.
    private static func datedValues(_ filter: String) -> [ClientFilterValue] {
        let windows = ["last3Months", "last6Months", "last12Months"].map {
            ClientFilterValue(ref: "\(filter)-\($0)", labelKey: "client.filter.value.\($0)", label: nil, parameters: [])
        }
        let since = ClientFilterValue(
            ref: "\(filter)-since", labelKey: "client.filter.value.since", label: nil,
            parameters: [ClientFilterValue.Parameter(name: "since", typeRaw: "date")]
        )
        return windows + [since]
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    /// `SearchOptionsSampleData`'s store: "My Clients"' sorts and filters, as
    /// dev serves them.
    static var searchOptionsSampleData: Self { .modifier(SearchOptionsSampleData()) }
}
