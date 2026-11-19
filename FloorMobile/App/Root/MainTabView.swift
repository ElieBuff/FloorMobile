//
//  MainTabView.swift
//  FloorMobile
//

import SwiftUI
import SwiftData

/// The app's root tab bar. Each tab owns its own `NavigationStack`, so
/// pushing a screen in one tab never leaks into another — the standard
/// pattern for a `TabView`, not a single stack shared across tabs.
///
/// The last tab, Search, sits apart from the rest, in its own round glass at
/// the bar's trailing end, as the mockups draw it, and opens straight into
/// typing: the keyboard comes up, the tab bar leaves, and the search field
/// sits just above the keyboard. Both come from the system search role with
/// `tabViewSearchActivation(.searchTabSelection)`: on iOS 27 a search tab
/// stays inside the bar without it (measured on iOS 27.2, 15/11).
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: AppTab = .home
    /// The Home tab's own navigation path, for the screens pushed from code.
    /// A tab whose every push comes from a link (Clients) needs none.
    @State private var homeRouter = Router<HomeRoute>()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .home) {
                NavigationStack(path: $homeRouter.path) {
                    HomeView()
                        // Declared on the stack's root content, never inside a
                        // lazy container (List, LazyVStack), where it might
                        // never register.
                        .navigationDestination(for: HomeRoute.self) { route in
                            switch route {
                            case .agenda(let date):
                                AgendaView(date: date)
                            }
                        }
                }
                .environment(homeRouter)
            } label: {
                label(String(localized: "Home"), systemImage: "house", tab: .home)
            }

            Tab(value: .clients) {
                NavigationStack {
                    // Declares its own destinations (`ClientsRoute`).
                    ClientsView()
                }
            } label: {
                label(String(localized: "Clients"), systemImage: "person.2", tab: .clients)
            }

            Tab(value: .more) {
                NavigationStack {
                    MoreView()
                }
            } label: {
                label(String(localized: "More"), systemImage: "square.grid.2x2", tab: .more)
            }

            Tab(value: .agent) {
                NavigationStack {
                    AgentView()
                }
            } label: {
                label(String(localized: "Agent"), systemImage: "sparkles", tab: .agent)
            }

            // Search keeps the system role; its icon color stays
            // system-managed.
            Tab(value: .search, role: .search) {
                NavigationStack {
                    SearchView()
                }
            }
        }
        // Selecting Search starts the search: field above the keyboard, and
        // the tab set apart from the bar on iOS 27 too.
        .tabViewSearchActivation(.searchTabSelection)
        // Icons carry their own baked color; this only sets the selected tab's
        // title (the system would otherwise tint it with the default accent).
        .tint(Color(.TabBar.iconActive))
    }

    // MARK: - Custom tab labels

    /// The iOS 26 Liquid Glass tab bar ignores icon-color customization, so we
    /// bake the color into each icon with `.alwaysOriginal` (which opts out of
    /// the system tint). Colors come from the `TabBar` tokens, which carry
    /// light/dark variants, so active/inactive follow the color scheme.
    private func label(_ title: String, systemImage: String, tab: AppTab) -> some View {
        let selected = selectedTab == tab
        let color: ColorResource = selected ? .TabBar.iconActive : .TabBar.iconInactive
        return Label {
            Text(title).foregroundStyle(Color(color))
        } icon: {
            Image(uiImage: tintedIcon(systemImage, filled: selected, color: color))
        }
    }

    /// An SF Symbol with the token color baked in for the current color scheme,
    /// so the tab bar renders it as-is instead of applying its own tint (baking
    /// also bypasses the system's automatic fill-on-select, so we request the
    /// `.fill` variant ourselves when selected — falling back to the base
    /// symbol for those, like `sparkles`, that have no filled variant).
    private func tintedIcon(_ systemName: String, filled: Bool, color: ColorResource) -> UIImage {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let resolved = UIColor(resource: color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        let base = filled ? (UIImage(systemName: "\(systemName).fill") ?? UIImage(systemName: systemName)) : UIImage(systemName: systemName)
        return base?.withTintColor(resolved, renderingMode: .alwaysOriginal) ?? UIImage()
    }
}

/// The app's top-level tabs, including the search tab.
enum AppTab: Hashable {
    case home
    case clients
    case more
    case agent
    case search
}

#Preview {
    MainTabView()
        .modelContainer(for: [AIAction.self, ClientSegment.self, ClientSort.self], inMemory: true)
        .environment(AppSession(auth: .preview, api: .preview))
}
