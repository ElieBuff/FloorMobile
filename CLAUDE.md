# FloorMobile

App iOS native **SwiftUI** de clienteling retail (clients, produits, agenda, messagerie temps réel), cliente de la plateforme Floor (`../FloorPlatform`). Réécriture from-scratch de l'ancienne app `../EmeriaMobile`, qui reste consultable comme référence fonctionnelle mais **pas comme modèle de code**.

Les échanges se font en français ; code, commentaires et noms en anglais.

## Règles de développement

**Pour tout code Swift/SwiftUI, suivre le skill [`floor-dev`](.claude/skills/floor-dev/SKILL.md)** : architecture Apple Model-View (`@Observable` + SwiftData, par feature, sans ViewModel), configuration Zitadel, conventions. **Pour les tests, le skill [`swiftui-testing`](.claude/skills/swiftui-testing/SKILL.md).** Le plan détaillé de la réécriture est dans [ARCHITECTURE-CIBLE.md](ARCHITECTURE-CIBLE.md).

## Stack

- iOS 26.5 min, Xcode 26, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Language mode **Swift 6** (réglage au niveau projet, sans override par target).
- Bundle : `ai.floorapp.floormobile` (+ suffixes `.dev`/`.staging` par environnement, via les xcconfig ; targets de test en `ai.floorapp.floormobile.tests`/`.uitests`).
- Dépendances SPM : autorisées quand elles apportent une vraie valeur ajoutée, à évaluer au cas par cas. Prévue : socket.io-client-swift, derrière `RealtimeService`.
- Auth : Zitadel OIDC natif, PKCE. Client ID et URLs dans le skill `floor-dev`.

## Build & tests

```bash
xcodebuild -list -project FloorMobile.xcodeproj

xcodebuild -project FloorMobile.xcodeproj -scheme "FloorMobile Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

.claude/skills/swiftui-testing/scripts/run-tests.sh            # tests unitaires
.claude/skills/swiftui-testing/scripts/run-tests.sh --ui       # UI tests
```

Simulateurs disponibles : famille iPhone 17. Trois schemes partagés — `FloorMobile Dev`/`Staging`/`Prod` — un par environnement (xcconfig `Dev`/`Staging`/`Prod` : issuer Zitadel, bundle id `ai.floorapp.floormobile[.dev|.staging]`, nom d'affichage). Le test UI du login lit ses identifiants dans `FloorMobileUITests/TestCredentialsSecret.json` (gitignoré, modèle dans `TestCredentials.example.json`) et se marque « skipped » si le fichier est absent.

## CI/CD & Release (Xcode Cloud)

**Modèle de branches (GitFlow léger)** : le travail quotidien se fait sur **`develop`** (branche par défaut) — chaque push y est testé par la CI, sans livraison. Merger `develop` → `main` est la décision de livrer un TestFlight staging. Les tags `v*` déclenchent la prod. Ne jamais committer directement sur `main`.

Trois workflows Xcode Cloud (stockés dans App Store Connect, **pas dans le dépôt**) :

| Workflow | Déclencheur | Actions |
|---|---|---|
| `CI` | push sur toute branche | build + tests unitaires (scheme Dev) |
| `Staging TestFlight` | push/merge sur `main` | tests + archive (scheme Staging) → TestFlight interne |
| `Prod Release` | tag `v*` | tests + archive (scheme Prod) → TestFlight / App Store |

Fiches App Store Connect : « Floor Clienteling Staging » (`ai.floorapp.floormobile.staging`) et « Floor Clienteling » (`ai.floorapp.floormobile`). Le numéro de build est auto-incrémenté par Xcode Cloud ; `ITSAppUsesNonExemptEncryption=false` est déclaré dans l'`Info.plist`.

**Rituel de release prod** (seuls gestes manuels du processus) :

1. Bumper `MARKETING_VERSION` (target → General → Version) — un choix, pas un compteur.
2. `git commit` + `git push` (la CI valide ce commit).
3. `git tag vX.Y.Z && git push origin vX.Y.Z` → déclenche `Prod Release`.
4. La soumission App Store finale reste un clic manuel dans App Store Connect.

À faire avant une vraie prod : remplacer les placeholders Zitadel de `Staging.xcconfig`/`Prod.xcconfig` (TODO dans les fichiers), domaine `login.staging.floorapp.ai`/`login.floorapp.ai`, branding de la page de login Zitadel.

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
