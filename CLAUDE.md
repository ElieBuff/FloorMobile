# FloorMobile

App iOS native **SwiftUI** de clienteling retail (clients, produits, agenda, messagerie temps réel), cliente de la plateforme Floor (`../FloorPlatform`). Réécriture from-scratch de l'ancienne app `../EmeriaMobile`, qui reste consultable comme référence fonctionnelle mais **pas comme modèle de code**.

Les échanges se font en français ; code, commentaires et noms en anglais.

## Règles de développement

**Pour tout code Swift/SwiftUI, suivre le skill [`floor-dev`](.claude/skills/floor-dev/SKILL.md)** : architecture Apple Model-View (`@Observable` + SwiftData, par feature, sans ViewModel), configuration Zitadel, conventions. **Pour les tests, le skill [`swiftui-testing`](.claude/skills/swiftui-testing/SKILL.md).** Le plan détaillé de la réécriture est dans [ARCHITECTURE-CIBLE.md](ARCHITECTURE-CIBLE.md).

## Stack

- iOS 26.5 min, Xcode 26, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Le language mode est encore Swift 5 : passer en Swift 6 avant d'écrire le socle.
- Bundle : `ai.floorapp.floormobile` (+ suffixes `.dev`/`.staging` par environnement, via les xcconfig ; targets de test en `ai.floorapp.floormobile.tests`/`.uitests`).
- Dépendances SPM : autorisées quand elles apportent une vraie valeur ajoutée, à évaluer au cas par cas. Prévue : socket.io-client-swift, derrière `RealtimeService`.
- Auth : Zitadel OIDC natif, PKCE. Client ID et URLs dans le skill `floor-dev`.

## Build & tests

```bash
xcodebuild -list -project FloorMobile.xcodeproj

xcodebuild -project FloorMobile.xcodeproj -scheme FloorMobile \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

.claude/skills/swiftui-testing/scripts/run-tests.sh            # tests unitaires
.claude/skills/swiftui-testing/scripts/run-tests.sh --ui       # UI tests
```

Simulateurs disponibles : famille iPhone 17. Aucun scheme n'est encore partagé (`xcshareddata/` absent) : à faire, avec les deux test targets rattachés, pour que `xcodebuild test` fonctionne.

## Structure cible (`FloorMobile/`)

```
FloorMobile/
├── App/            FloorMobileApp.swift, RootView, AppSession (@Observable)
├── Core/           Networking, Auth, Persistence, Realtime, Sync
├── DesignSystem/   tokens + composants (repris d'EmeriaMobile, Dynamic Type et a11y ajoutés)
└── Features/       Clients, Products, Agenda, Feeds, Conversations, Authentication
```

État au 7 septembre 2026 : projet issu du template Xcode (`ContentView`, `Item`). `RootView.swift`, `SyncManager.swift` et `LoadingView.swift` ont été créés **à la racine du dépôt**, hors du dossier `FloorMobile/` : à déplacer dans `App/` et `Core/Sync/`.

## Ordre de réécriture

Suivre §14 du plan cible : socle (config, Keychain, APIClient, AuthManager, erreurs, logs) → session et login Zitadel → SwiftData + SyncEngine → features par valeur (Clients, Agenda, Feeds, Conversations, Products) → tests et previews. Chaque jalon compile et se commite.

## À reprendre d'EmeriaMobile

Design system (`Presentation/Core/DesignSystem`), `KeychainManager` (en le passant en `actor` et en ajoutant `kSecAttrAccessible`), le moteur `SyncTask` à dépendances (réécrit en `ModelActor`), les routes typées du `AppRouter`, la config xcconfig Dev/Prod. Rien d'autre.

## Points de vigilance connus

- Jamais d'identifiant, mot de passe ou token en dur ni dans les logs : l'ancienne app en avait.
- Un seul `AuthManager` sérialise le refresh de token : l'ancienne app avait quatre chemins de refresh concurrents.
- Chaque `@Model` porte un `tenantId` et un `VersionedSchema` : l'ancienne app mélangeait les tenants et n'avait pas de migration.
