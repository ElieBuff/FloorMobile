# Architecture cible FloorMobile (ex-EmeriaMobile) — basée sur les best practices Apple 2026

> Proposition pour la réécriture big-bang. Sources : documentation Apple ("Managing model data in your app"), WWDC 2025 (iOS 26, Swift 6.2) et WWDC 2026 (iOS 27 — ⚠️ les features iOS 27 sont signalées explicitement, elles exigent de monter le target minimum).

## 1. Verdict sur l'existant

Ton intuition est correcte et alignée avec la position d'Apple : MVVM + Clean Architecture n'est pas adapté à SwiftUI. Aujourd'hui, une action simple (ex. créer une tâche d'agenda) traverse : View → ViewModel/Store → UseCase → Repository (protocole + impl) → DataSource (protocole + impl) → DTO → Entity Domain → Entity SwiftData. Soit 6 à 8 fichiers par opération, pour ~20 000 lignes dont l'essentiel est de la plomberie de mapping.

La position Apple (docs "Managing model data", WWDC "Discover Observation") : **« In SwiftUI, the views are the view model »**. La vue EST la couche de présentation ; on ne duplique pas son état dans un objet intermédiaire. C'est exactement le pattern déjà atteint par `ClientsView` (`@Query` direct, zéro ViewModel) — la seule feature du projet où ajouter un champ ne demande de toucher qu'un fichier.

## 2. La stack recommandée par Apple en 2026

| Besoin | Outil | Persiste |
|---|---|---|
| État local d'une vue | `@State` | non |
| État partagé en RAM, accessible partout (session, user, theme) | classe `@Observable` injectée via `.environment(...)` | non |
| Donnée de référence / offline (source de vérité) | SwiftData `@Model` + `@Query` | oui |
| Écriture/sync en arrière-plan | `@ModelActor` | — |
| Secrets (tokens) | Keychain (existant, à conserver) | oui |
| Réagir à un changement d'état hors vue | `Observations` AsyncSequence (Swift 6.2) | — |

Points d'appui 2025-2026 :

- **Swift 6.2 "Approachable Concurrency"** : le mode *default MainActor isolation* (SE-0466) fait tourner tout le code app sur le MainActor par défaut. Fini les annotations `@MainActor` partout — on ne sort du main thread que volontairement (`@concurrent`, `@ModelActor`). À activer dans les build settings du nouveau projet.
- **`Observations` (SE-0475, Swift 6.2)** : observer un `@Observable` hors SwiftUI via AsyncSequence transactionnel. Remplace les callbacks maison type `onPostLogin`/`onTokenRefreshNeeded`.
- **@Observable + environment** : le pattern officiel pour ton besoin de « donnée en cache accessible depuis n'importe quelle page » — un store racine injecté une fois, lu partout via `@Environment(Type.self)`, avec re-render au niveau propriété (pas objet).

### Nouveautés iOS 27 (⚠️ WWDC juin 2026 — nécessite target iOS 27)

- **`ResultsObserver`** : l'équivalent de `@Query` hors des vues (fetch + observation SwiftData dans n'importe quelle classe). Idéal pour `ThemeManager` : plus besoin de charger le cache à la main depuis SwiftData.
- **`HistoryObserver`** : signal observable sur l'historique de persistance, filtrable par auteur — l'outil officiel pour un moteur de sync serveur (push des changements locaux sans boucle infinie).
- **`@Query(sectionBy:)`** : groupement natif dans la query — remplace l'index manuel `[Date: [Activity]]` de `ActivityStore` pour l'agenda.
- **`@Attribute(.codable)`** : persister un type non-@Model (escape hatch ; pas de predicate/tri/migration dessus).
- **`@State` lazy** : les `@Observable` stockés en `@State` ne sont plus réinitialisés à chaque init de la vue.
- **`AsyncImage` avec cache HTTP natif** : peut remplacer `RemoteImage`.

Ton target actuel est iOS 26.1 : tout le cœur de l'architecture (sections 3-7) fonctionne en iOS 26. Les items ci-dessus sont des simplifications à prendre si tu passes le minimum à iOS 27.

## 3. Architecture proposée : Model-View par feature

```
FloorMobile/
├── App/
│   ├── FloorMobileApp.swift          // @main, injection des environnements
│   └── AppSession.swift               // @Observable : le "cache global" (voir §4)
├── DesignSystem/                      // existant, conservé tel quel
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift            // URLSession + async/await (~100 lignes)
│   │   └── AuthManager.swift          // actor : tokens, refresh sérialisé
│   ├── Persistence/
│   │   ├── KeychainManager.swift      // conservé
│   │   └── DataStore.swift            // ModelContainer + schema
│   ├── Realtime/
│   │   └── RealtimeService.swift      // Socket.IO → AsyncStream par événement
│   └── Sync/
│       └── SyncEngine.swift           // @ModelActor, moteur à dépendances (conservé)
└── Features/
    ├── Clients/       // ClientsView + Client(@Model) + ClientService
    ├── Products/      // vues + Product(@Model) + ProductService
    ├── Agenda/        // vues + Activity + ActivityStore(@Observable) + ActivityService
    ├── Feeds/         // vues + FeedItem + FeedStore(@Observable) + FeedService
    ├── Conversations/ // vues + modèles + ConversationService (+ realtime)
    └── Authentication/ // LoginView (état local @State)
```

Règles :

- **Une feature = un dossier** : vues + modèles + un `Service` (la classe qui parle à l'API). Pas de sous-dossiers View/ViewModel/Store/DTO.
- **Pas de ViewModel.** L'état d'écran vit en `@State` dans la vue ; la logique métier vit dans les modèles et services.
- **Pas de protocole + impl par défaut.** Un protocole seulement quand un besoin réel existe (tests d'un composant critique, ex. `AuthManager`). Les Mocks passent par des données de preview / un `APIClient` stub, pas par une hiérarchie DataSource.
- **DTO seulement si l'API est tordue.** Sinon le `@Model` ou un struct `Codable` décode directement la réponse.

## 4. Le « cache global » — réponse au besoin identifié dans le code actuel

Aujourd'hui la donnée accessible « depuis n'importe quelle page » passe par 4 mécanismes hétérogènes : `GeneralInfoStorage.current()` (lecture statique UserDefaults, ex. `FeedItemCommentsView`), `ThemeManager.shared` (singleton + cache RAM rechargé depuis SwiftData), `ReferenceValueHelper` (fetch SwiftData), et les stores injectés (`activityStore`, `feedItemStore`). C'est ce qui est remplacé par deux mécanismes seulement :

**a) RAM partagée → un `AppSession` @Observable unique, injecté à la racine :**

```swift
@Observable
final class AppSession {
    var state: SessionState = .unauthenticated   // login/sync/ready
    var generalInfo: GeneralInfo?                // user, SA, store, storeCode
    var theme: Theme?                            // couleurs + assets chargés
    var realtimeState: RealtimeConnectionState = .disconnected
}

// racine :
.environment(session)
// n'importe quelle vue :
@Environment(AppSession.self) private var session
```

Un seul objet, observable au niveau propriété (une vue qui lit `generalInfo` ne re-render pas quand `realtimeState` change). Plus de singletons, plus de lectures statiques, plus de 4 `EnvironmentKey` avec des `defaultValue` qui instancient des containers DI parasites.

**b) Données de référence / offline → SwiftData, les vues lisent via `@Query` :**

Clients, Products/Categories/Variants, ReferenceValues, ThemeColors/Assets restent des `@Model`. La vue lit `@Query` (local-first, offline gratuit), le `SyncEngine` remplit en arrière-plan. C'est le pattern `ClientsView` généralisé. Pour un accès hors vue (ex. `ReferenceValueHelper`), un fetch direct sur le `ModelContext` suffit — et en iOS 27, `ResultsObserver` le rend observable.

Reste online-only (cache RAM dans le store de la feature) : Feeds, Conversations, Agenda — sauf si tu veux l'agenda offline, auquel cas `Activity` devient un `@Model` de plus.

## 5. Réseau : URLSession, sans Alamofire

Recommandation : **URLSession pur** (tranche la décision ouverte du cadrage).

- Ton usage d'Alamofire se limite à du REST JSON + un interceptor : ~150 lignes d'URLSession async/await couvrent tout (`authURL` vs `apiBaseURL` dynamique multi-tenant inclus).
- Le refresh token doit être **sérialisé dans un `actor`** — corrige la race condition connue sur 401 parallèles que l'interceptor Alamofire actuel ne gère pas :

```swift
actor AuthManager {
    private var refreshTask: Task<String, Error>?

    func validToken() async throws -> String { /* renvoie ou refresh */ }

    func refreshedToken() async throws -> String {
        if let task = refreshTask { return try await task.value }  // refresh en cours → on attend
        let task = Task { /* appel refresh + Keychain */ }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
```

- Une dépendance de moins ; et la direction Swift officielle va vers une couche réseau standardisée (Networking Workgroup 2026, vision swift-evolution) construite sur URLSession/async — pas sur Alamofire.

## 6. Realtime : AsyncStream au lieu de callbacks

`RealtimeService` (garde Socket.IO comme transport) expose des `AsyncStream` typés par événement au lieu de `on`/`off` bruts :

```swift
for await interaction in realtime.interactions(threadId: id) {
    thread.append(interaction)
}
```

Le service **multiplexe** les abonnés en interne : un seul handler Socket.IO par événement, N streams. Corrige structurellement le bug actuel où `off("interaction:created")` d'une vue détruit aussi le listener global de `GlobalEventManager`. L'annulation de la `Task` de la vue ferme son stream sans toucher aux autres. Le refresh de token à la reconnexion passe par le même `AuthManager`.

## 7. Ce qui disparaît, ce qui reste

**Supprimé** (≈ 170 fichiers, plus de la moitié du code) : les 46 UseCases, tous les Repositories (protocoles + impls), tous les DataSources (+ Mocks), la quasi-totalité des DTOs, les 9 containers DI, les ViewModels, `GeneralInfoStorage`, `AppConfig` (doublon de `AppConfiguration` — en garder un seul), `SOCKETIO_USAGE_EXAMPLE.swift`, `MessagesView`, `OtherView`.

**Conservé** : DesignSystem complet, `KeychainManager` (en corrigeant `save`/`delete` hors queue — ou remplacer la queue par un `actor`), le moteur de sync à dépendances (`SyncTask` + détection de cycle, réécrit en `@ModelActor`), `AppRouter`/Routes (simplifié), la config xcconfig Dev/Prod.

**Ordre de grandeur** : une action type « ajouter un champ + un appel API » passe de 6-8 fichiers touchés à 1-2 (la vue, le service ou le modèle).

## 8. Recommandations avancées

### 8.1 Concurrence (Swift 6.2)

Activer dès la création du projet : `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Tout le code app tourne sur le MainActor par défaut ; on ne sort du main thread que là où c'est mesurablement utile : `@concurrent` pour le CPU-bound (parsing lourd, traitement d'images), `@ModelActor` pour les écritures SwiftData de masse (sync). C'est le modèle « single-threaded par défaut » prôné par Apple — il élimine 90 % des erreurs de concurrence du projet actuel (Keychain, caches).

### 8.2 Gestion d'erreurs

Une seule hiérarchie : `enum AppError: Error` avec cas typés (`network(NetworkError)`, `unauthorized`, `sync(SyncError)`...) et `LocalizedError` pour les messages UI. Règle : ne jamais écraser la sémantique (l'`APIClient` actuel convertit tout en `.decodingError`, y compris les erreurs HTTP — à ne pas reproduire). Les vues affichent via un modificateur unique `.appErrorAlert($error)` plutôt que du handling ad hoc par écran.

### 8.3 Logging & observabilité

`os.Logger` natif (unified logging) avec un logger par sous-système (`network`, `sync`, `realtime`, `ui`) — garder `AppLogger` comme façade fine. `signpost` sur les opérations longues (sync, fetch produits) pour profiler dans Instruments. Supprimer les ~75 lignes de dump d'erreur verbeux de l'APIClient au profit de logs structurés.

### 8.4 Tests (dette actuelle : 0 test)

- **Swift Testing** (`@Test`, `#expect`) — le framework par défaut depuis Xcode 16, déjà présent dans ton target de test.
- Tester les **Services et modèles**, pas les vues : `APIClient` stubé via un `URLProtocol` custom (pas besoin de protocole DataSource), SwiftData en `ModelConfiguration(isStoredInMemoryOnly: true)`, `AuthManager` testé sur la sérialisation du refresh (le bug historique).
- Vues : couvrir par des **Previews** systématiques (avec `.environment(AppSession.preview)` + container in-memory pré-rempli) — c'est aussi ce qui remplace les Mock DataSources.
- Cible pragmatique : ~80 % sur Core (networking, sync, auth), previews sur toutes les vues, 2-3 UI tests de smoke (login → home).

### 8.5 Localisation

**String Catalog (`.xcstrings`)** dès le premier écran — le projet actuel mélange FR/EN en dur sans aucun catalogue. Xcode extrait automatiquement les literals SwiftUI ; c'est quasi gratuit si fait dès le début, pénible après.

### 8.6 Navigation & deep links

Garder l'idée `AppRouter` : un `@Observable` avec un `NavigationPath` par onglet, `enum` de routes par feature, injecté en environment. Implémenter réellement les deep links (`emeriaapp://activity/{id}`) — le squelette existe mais les handlers ne font que logger. `.navigationDestination(for:)` par feature, pas de switch géant central.

### 8.7 Modularisation — ne pas sur-découper

À ~20 k lignes (et moins après réécriture), **un seul target app suffit**. Exception utile : extraire `DesignSystem` en package SPM local (compile plus vite, previews isolées, réutilisable si un jour une target Watch/widget arrive). Ne pas faire un package par feature — c'est le même excès que Clean Architecture, version build system.

### 8.8 Hygiène projet

- **Partager les schemes** `FloorMobile-Dev`/`-Prod` (`xcshareddata`) — actuellement ils ne sont que dans ton `xcuserdata`, un clone frais ne build pas pareil.
- Corriger la divergence de bundle id (doc `com.app.emeria.FloorMobile` vs xcconfig `com.emeriaapp.mobile`).
- CI dès le début : GitHub Actions ou Xcode Cloud — build + tests + SwiftLint sur chaque PR. Avec un seul commit git aujourd'hui, c'est le bon moment.

## 9. Packages : garder / supprimer / ajouter / éviter

Philosophie 2026 : **SPM uniquement**, le moins de dépendances possible (Apple a comblé la plupart des besoins), et chaque lib tierce isolée derrière une petite façade à toi (comme `RealtimeService` pour Socket.IO) pour rester remplaçable.

### À supprimer (4 des 5 dépendances actuelles)

| Package | Remplacé par |
|---|---|
| **Alamofire** | URLSession async/await (§5). Ton usage est du REST JSON simple ; l'interceptor devient un `actor` de ~50 lignes. |
| **PopupView** | `.sheet`, `.alert`, `.presentationDetents`, overlays natifs — largement suffisants depuis iOS 16, a fortiori en iOS 26. |
| **WrappingHStack** | Un `Layout` custom (~40 lignes, protocole natif) pour le flow des tags. |
| **swiftui-introspect** | Rien — c'est un hack par nature (accès UIKit interne), fragile à chaque release d'OS. Résolu dans ton `Package.resolved` mais quasi pas utilisé : suppression gratuite. |

### À garder

| Package | Pourquoi |
|---|---|
| **socket.io-client-swift** | Ton backend parle le protocole Socket.IO (rooms, acks) — pas remplaçable par un simple client WebSocket (`URLSessionWebSocketTask`, NWWebSocket). La lib est maintenue mais évolue lentement : c'est LA dépendance à isoler derrière `RealtimeService`. Si un jour le backend migre vers du WebSocket pur ou SSE, `URLSessionWebSocketTask` natif prend le relais sans toucher aux features. |

### À ajouter (sélectivement)

| Besoin | Recommandation | Alternative |
|---|---|---|
| **Images produits/clients** (cache disque, prefetch, downsampling) | **Nuke** — le plus performant et moderne (async/await natif, LazyImage SwiftUI, prefetching, progressive JPEG/WebP/HEIF). Important pour une app de clienteling qui affiche des catalogues produits. Garder ta façade `RemoteImage` au-dessus. | Kingfisher (équivalent, API plus ancienne). ⚠️ iOS 27 : `AsyncImage` gagne le cache HTTP natif — suffisant pour les cas simples, mais pas de cache disque contrôlé ni prefetch ; Nuke reste justifié pour le catalogue. |
| **Crash reporting** | **Sentry** — meilleur choix pour un SaaS B2B : contexte riche (breadcrumbs, replays), couvre aussi ton backend (projet unifié front/back), alerting Slack. | Firebase Crashlytics si tu veux du gratuit/simple — mais ça embarque tout le SDK Firebase. |
| **Analytics produit** | **TelemetryDeck** — privacy-first (zéro PII), SDK ~200 KB, adapté au positionnement luxe/clienteling où la confidentialité des données clients est sensible. | Firebase Analytics (lourd, données chez Google — à éviter vu ton domaine). |
| **Push notifications** | **APNs direct depuis ton backend** (token-based auth). Tu contrôles déjà le backend (Socket.IO) ; ajouter Firebase juste pour FCM n'apporte rien sur iOS — FCM n'est qu'un proxy vers APNs. | Firebase Messaging seulement si le backend veut un seul canal iOS+Android. |

**Sur Firebase globalement** : non recommandé ici. Son intérêt est le bundle tout-en-un (auth, DB, push, analytics) pour des apps sans backend. Tu as déjà ton backend, ton auth, ton realtime — il ne resterait que Crashlytics/Analytics, mieux servis par Sentry + TelemetryDeck, plus légers et plus respectueux des données clients.

### Outillage (dev, pas runtime)

- **SwiftLint** + **swift-format** (intégré à Xcode 16+) — config partagée, appliqués en CI.
- Pas de framework de DI (Swinject, Factory, swift-dependencies) : `@Environment` + init injection couvrent le besoin à cette échelle. `swift-dependencies` (Point-Free) est le seul défendable si le graphe grossit — pas maintenant.

### À éviter

- **TCA (Composable Architecture)** : puissant mais réintroduit exactement ce que tu fuis — indirection, boilerplate, courbe d'apprentissage, couplage à une lib tierce pour toute l'architecture.
- **RxSwift / frameworks réactifs** : obsolètes face à async/await + Observation.
- **CocoaPods** : en fin de vie (mode maintenance), SPM uniquement.

## 10. Décisions à prendre avant de coder

1. **Target minimum : iOS 26 ou iOS 27 ?** iOS 27 simplifie sync (`HistoryObserver`), agenda (`sectionBy`), theme (`ResultsObserver`) — mais sort à l'automne 2026.
2. **Agenda offline ?** Si oui → `Activity` devient `@Model` + `@Query(sectionBy:)`.
3. **Mode Swift 6.2 "default MainActor"** : recommandé (à activer dès la création du projet).
4. **Sentry + TelemetryDeck vs Firebase** : trancher selon budget et exigences de confidentialité des maisons clientes.
5. **Push** : APNs direct (recommandé) ou FCM si unification iOS+Android côté backend.

---

## 11. Patterns de code de référence

Les squelettes à copier lors de la réécriture. Chaque pattern remplace une pile complète de l'ancien code.

### 11.1 Le cache global RAM — `AppSession`

Remplace : `GeneralInfoStorage`, `ThemeManager.shared`, les 4 `EnvironmentKey`, les lectures statiques.

```swift
@Observable
final class AppSession {
    enum State { case unauthenticated, authenticating, syncing(Double), ready, error(AppError) }

    var state: State = .unauthenticated
    var generalInfo: GeneralInfo?          // user, SA, store, storeCode
    var theme: Theme?
    var realtimeState: RealtimeConnectionState = .disconnected

    // Logique métier DANS le modèle (pas de UseCase) :
    func login(email: String, password: String) async { ... }
    func logout() async { ... }
}

// Injection unique à la racine :
@main struct FloorMobileApp: App {
    @State private var session = AppSession()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .modelContainer(for: [Client.self, Product.self, ProductCategory.self,
                                      ProductVariant.self, ReferenceValue.self,
                                      ThemeColor.self, ThemeAsset.self])
        }
    }
}

// Lecture depuis n'importe quelle vue :
@Environment(AppSession.self) private var session
```

Grâce à Observation, une vue qui lit `session.generalInfo` ne re-render PAS quand `realtimeState` change (tracking au niveau propriété).

### 11.2 API → SwiftData : le DTO léger, un seul saut

Remplace : DTO → `toDomain()` → Entity Domain → `fromDomain()` → Entity SwiftData (3 types, 2 mappings) par 2 types, 1 mapping, colocalisés dans la feature.

```swift
// Miroir exact du JSON (le "DTO" — ~10 lignes, même fichier que le service)
struct ClientResponse: Codable {
    let id: String
    let first_name: String
    let last_name: String
    let opt_in: Bool
}

@Model
final class Client {
    #Unique<Client>([\.id])            // insert = upsert automatique
    #Index<Client>([\.lastName])       // perf de tri/recherche
    var id: String
    var firstName: String
    var lastName: String
    var optIn: Bool

    init(from r: ClientResponse) {
        id = r.id; firstName = r.first_name; lastName = r.last_name; optIn = r.opt_in
    }
}
```

Règles : si le JSON colle au modèle (ou juste du snake_case → `.convertFromSnakeCase`), on peut sauter le struct et rendre le `@Model` `Codable` (init manuel — le macro complique la synthèse). En pratique le struct réponse est le compromis le plus robuste. Ne JAMAIS réintroduire d'entité « Domain » intermédiaire.

### 11.3 `APIClient` URLSession (remplace Alamofire, ~100 lignes)

```swift
final class APIClient {
    private let auth: AuthManager
    private let baseURL: () -> URL      // closure : gère l'URL multi-tenant dynamique post-login

    func get<T: Decodable>(_ type: T.Type, _ path: String,
                           query: [URLQueryItem] = []) async throws -> T {
        try await send(type, method: "GET", path: path, query: query)
    }
    func post<T: Decodable, B: Encodable>(_ type: T.Type, _ path: String, body: B) async throws -> T { ... }

    private func send<T: Decodable>(_ type: T.Type, method: String, path: String, ...) async throws -> T {
        var request = URLRequest(url: ...)
        request.setValue("Bearer \(try await auth.validToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.network(.invalidResponse) }
        if http.statusCode == 401 {
            // UN SEUL retry, avec token rafraîchi par l'acteur (sérialisé)
            request.setValue("Bearer \(try await auth.refreshedToken())", forHTTPHeaderField: "Authorization")
            ... // renvoyer une fois
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.network(.http(http.statusCode, data))   // NE PAS écraser en decodingError
        }
        return try decoder.decode(T.self, from: data)
    }
}
```

### 11.4 `AuthManager` — refresh sérialisé (corrige la race 401)

```swift
actor AuthManager {
    private let keychain: KeychainManager
    private var refreshTask: Task<String, Error>?

    func validToken() async throws -> String {
        guard let token = keychain.accessToken, !isExpired(token) else {
            return try await refreshedToken()
        }
        return token
    }

    func refreshedToken() async throws -> String {
        if let task = refreshTask { return try await task.value }   // refresh en cours → tout le monde attend le même
        let task = Task<String, Error> {
            defer { refreshTask = nil }
            let new = try await callRefreshEndpoint(keychain.refreshToken)
            keychain.save(new)
            return new.accessToken
        }
        refreshTask = task
        return try await task.value
    }
}
```

### 11.5 `SyncEngine` — écriture en arrière-plan

Garde ton moteur à dépendances (`SyncTask` + détection de cycle + `withThrowingTaskGroup` — c'est un des points forts de l'existant), réécrit en `@ModelActor` :

```swift
@ModelActor
actor SyncEngine {
    func syncClients(api: APIClient) async throws {
        let responses = try await api.get([ClientResponse].self, "/clients")
        for r in responses { modelContext.insert(Client(from: r)) }   // upsert via #Unique
        try modelContext.save()
        // Les @Query des vues se mettent à jour automatiquement.
    }
}
```

Ordre : app-config d'abord (obligatoire), puis theme / clients / categories en parallèle, products dépend de categories. Progress reporté dans `session.state = .syncing(x)` (au passage : brancher réellement l'état `.syncing`, mort dans le code actuel).

### 11.6 `RealtimeService` — Socket.IO derrière des AsyncStream

Corrige structurellement le bug `off()` (un seul handler socket par événement, N abonnés multiplexés) :

```swift
@Observable
final class RealtimeService {
    private var continuations: [String: [UUID: AsyncStream<Data>.Continuation]] = [:]

    func events(_ event: String, room: String? = nil) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let id = UUID()
            if continuations[event] == nil {
                socket.on(event) { [weak self] data, _ in     // handler socket UNIQUE par event
                    self?.continuations[event]?.values.forEach { $0.yield(data) }
                }
            }
            continuations[event, default: [:]][id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.remove(event: event, id: id) }  // ne touche pas les autres abonnés
            }
        }
    }
}

// Dans une vue de conversation :
.task {
    await realtime.joinRoom("thread:\(threadId)")
    for await data in realtime.events("interaction:created") {
        if let interaction = try? decode(Interaction.self, data) { messages.append(interaction) }
    }
    // La Task est annulée quand la vue disparaît → stream fermé proprement, room quittée dans defer
}
```

### 11.7 Une feature complète type — Agenda

```
Features/Agenda/
├── AgendaView.swift          // @Query ou lecture du store, @State pour filtres
├── ActivityDetailView.swift
├── ActivityFormView.swift    // @State pour le brouillon du formulaire (pas de FormViewModel)
├── Activity.swift            // le modèle (+ ActivityResponse Codable dans le même fichier)
└── ActivityService.swift     // les appels API : list/create/update/delete (~80 lignes)
```

Le formulaire : `@State private var draft = ActivityDraft()` dans la vue, validation dans une extension du modèle (`draft.isValid`), sauvegarde = `try await service.create(draft)`. C'est TOUT — contre View + FormViewModel + 2 UseCases + Repository + DataSource + 2 DTOs aujourd'hui.

## 12. SwiftData en pratique — pièges et solutions

- **Upsert** : `#Unique<T>([\.id])` + `insert` remplace le fetch-puis-update manuel des `Local*DataSource` actuels.
- **Schema explicite** : lister TOUS les `@Model` dans le `modelContainer` (l'oubli actuel de `ProductVariantEntity`, rattrapé par inférence de relation, est fragile).
- **Relations** : `@Relationship(deleteRule: .cascade)` déclaré d'un seul côté, l'inverse est inféré. Éviter les tableaux non-relationnels de types complexes (stockés en blob).
- **Migrations** : dès la v1 livrée, versionner (`VersionedSchema` + `SchemaMigrationPlan`). Tant que l'app n'est pas en prod, changer le schéma librement (delete + resync — tu as déjà `clearLocalData`).
- **Threading** : le `ModelContext` du `mainContext` sur le MainActor pour les vues ; TOUTES les écritures de masse dans un `@ModelActor` (jamais le pattern actuel `backgroundContext` recréé à chaque accès). Un objet `@Model` ne traverse jamais les acteurs : passer des `PersistentIdentifier` ou des valeurs.
- **`@Query` avec filtre dynamique** : initialiser la query dans `init(...)` de la vue (`_clients = Query(filter: #Predicate { ... })`) — pattern pour la recherche/filtres de `ClientsView`.
- **Preview** : `ModelContainer` in-memory pré-rempli dans un `PreviewModifier` réutilisable — remplace les Mock DataSources.
- ⚠️ iOS 27 : `sectionBy:` (groupement natif — agenda par jour), `ResultsObserver` (query observable hors vue), `HistoryObserver` (réagir aux changements pour push serveur), `@Attribute(.codable)`.

## 13. Correspondance ancien → nouveau

| Ancien (fichiers) | Nouveau |
|---|---|
| `AppDIContainer` + 8 containers (~900 L) | `FloorMobileApp.init` : ~15 lignes d'instanciation + `.environment(...)` |
| `SessionManager` + 6 UseCases auth + Repository + 2 DataSources + `TokenStorage*` | `AppSession` (@Observable) + `AuthManager` (actor) + `KeychainManager` (conservé) |
| `APIClient` Alamofire (285 L) + Interceptor (92 L) | `APIClient` URLSession (~100 L, retry 401 intégré) |
| `SyncManager` + `SetupRepositoryImpl` + Setup UseCases/DataSources/DTOs | `SyncEngine` (@ModelActor) — moteur de dépendances conservé |
| `RealtimeManager` + `GlobalEventManager` + 5 UseCases SocketIO + 2 DataSources | `RealtimeService` (AsyncStream multiplexés) |
| Par feature : ViewModel/Store + UseCases + Repository + DataSources + DTOs + Entities ×2 | Vues + 1 `@Model` (ou struct) + 1 `Service` |
| `ThemeManager.shared` + entités theme | `session.theme` chargé par `SyncEngine` ; entités `ThemeColor`/`ThemeAsset` conservées |
| `GeneralInfoStorage` (statique UserDefaults) | `session.generalInfo` (RAM) + persistance UserDefaults dans `AppSession` si besoin au relaunch |
| Mock DataSources (~1 500 L) | Previews + `URLProtocol` stub pour les tests |
| `AppConfig` + `AppConfiguration` (doublon) | Un seul `AppConfiguration` |

## 14. Ordre de réécriture proposé (big-bang maîtrisé)

1. **Socle** (1er jalon compilable) : nouveau groupe `Core/` — `AppConfiguration` unifiée, `KeychainManager` (corrigé en actor), `APIClient`, `AuthManager`, `AppError`, `os.Logger`. Activer default MainActor + String Catalog + schemes partagés + CI.
2. **Session** : `AppSession`, login/logout, `RootView` qui switch sur `session.state`. → App qui se connecte.
3. **SwiftData + Sync** : les 7 `@Model` renommés sans suffixe Entity, `SyncEngine`, theme branché. → App qui synchronise.
4. **Features par valeur décroissante** : Clients (quasi fini — renommages), Agenda, Feeds, Conversations (+ `RealtimeService`), Products, Search/More.
5. **Suppression** : `Domain/`, `Data/`, `Infrastructure/DI`, ViewModels, vestiges (`MessagesView`, `OtherView`, `SOCKETIO_USAGE_EXAMPLE`). Rien ne doit plus les référencer.
6. **Filet** : tests Core (auth/réseau/sync), previews sur toutes les vues, 2-3 UI tests de smoke.

Chaque jalon = un état compilable et commitable. Le point 4 peut se faire feature par feature en gardant temporairement l'ancien code des features pas encore migrées — mais comme les deux mondes partagent `Core/`, ne pas laisser traîner : l'expérience du projet actuel montre que les demi-migrations s'installent.

## 15. Checklist de démarrage

- [ ] `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, Swift 6 language mode
- [ ] Target minimum tranché (iOS 26 vs 27) — voir §10.1
- [ ] Schemes Dev/Prod partagés (`xcshareddata`), bundle id unifié
- [ ] String Catalog créé (`Localizable.xcstrings`), FR + EN
- [ ] SwiftLint + swift-format configurés, CI GitHub Actions (build + test + lint)
- [ ] SPM : retirer Alamofire/PopupView/WrappingHStack/introspect ; ajouter Nuke (+ Sentry/TelemetryDeck si tranché)
- [ ] `DesignSystem` extrait en package SPM local (optionnel mais recommandé)
- [ ] Ancien code : figer (aucune évolution sur Domain/Data pendant la réécriture)
