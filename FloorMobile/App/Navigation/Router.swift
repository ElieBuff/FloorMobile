//
//  Router.swift
//  FloorMobile
//

import Observation

/// The navigation path of one `NavigationStack`, as an observable object so
/// any view in that stack — or code outside it, like a deep link handler —
/// can push and pop without threading closures through the view tree.
///
/// One instance per tab: each tab owns its own stack and its own path, so
/// coming back to a tab finds it where it was left. Bind it with
/// `NavigationStack(path: $router.path)` and inject it with
/// `.environment(router)`; views read it back with
/// `@Environment(Router<HomeRoute>.self)`.
@Observable
final class Router<Route: Hashable> {
    var path: [Route] = []

    init(path: [Route] = []) {
        self.path = path
    }

    func push(_ route: Route) {
        path.append(route)
    }

    /// Pops the top screen; a no-op at the root.
    func pop() {
        _ = path.popLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}
