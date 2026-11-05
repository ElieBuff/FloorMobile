# FloorMobile

App iOS native **SwiftUI** de clienteling retail (clients, produits, agenda, messagerie temps réel), cliente de la plateforme Floor (`../FloorPlatform`). Réécriture from-scratch de l'ancienne app `../EmeriaMobile`, qui reste consultable comme référence fonctionnelle mais **pas comme modèle de code**.

Les échanges se font en français ; code, commentaires et noms en anglais.

## Règles de développement

**Pour tout code Swift/SwiftUI, suivre le skill [`floor-dev`](.claude/skills/floor-dev/SKILL.md)** : architecture Apple Model-View (`@Observable` + SwiftData, par feature, sans ViewModel), configuration Zitadel, conventions. **Pour les tests, le skill [`swiftui-testing`](.claude/skills/swiftui-testing/SKILL.md).** Le plan détaillé de la réécriture est dans [ARCHITECTURE-CIBLE.md](ARCHITECTURE-CIBLE.md).

**Composants réutilisables d'abord.** Tout élément qui peut servir plusieurs fois (barre de recherche, avatar, rangée…) est un composant réutilisable, pas une vue recopiée. Avant d'en créer un, vérifier qu'il n'existe pas déjà (`DesignSystem/`, `Core/Extensions/`, `Features/*/Views/Components/`) et partir de ce que l'app fait déjà. Le code doit être très propre.

**En mode plan, avant de présenter un plan : appliquer le skill [`plan-review`](.claude/skills/plan-review/SKILL.md)** — relecture par l'agent `plan-critic` (`.claude/agents/plan-critic.md`), 3 tours au plus — sauf si l'utilisateur a dit « sans relecture ».

**Après l'approbation d'un plan : appliquer le skill [`qa-review`](.claude/skills/qa-review/SKILL.md)** — photo de l'arbre avant la première édition, puis QA du code par l'agent `qa-reviewer` (`.claude/agents/qa-reviewer.md`) à la fin, simple ou renforcé (workflow `qa-deep`) selon la ligne « QA proposé » du plan, 3 tours au plus — sauf si l'utilisateur a dit « sans QA ». Le QA lance lui-même le build et les tests unitaires, jamais les tests UI. Les deux relecteurs partagent leurs règles : [`.claude/review/house-rules.md`](.claude/review/house-rules.md).

## Stack

- iOS 26.5 min, Xcode 27 (simulateurs sous iOS 27, aucun runtime 26.x installé), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Language mode **Swift 6** (réglage au niveau projet, sans override par target).
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

**Avant de merger `develop` sur `main` ou de poser un tag `v*` : suivre le skill [`release`](.claude/skills/release/SKILL.md)** — workflows Xcode Cloud, rituel de release prod, et les prérequis (BFF de staging, migrations, `FloorSchemaV2`) sans lesquels la livraison casse l'app des testeurs. Chaque prérequis serveur qu'une fonctionnalité ajoute s'écrit dans ce skill.

## À reprendre d'EmeriaMobile

Design system (`Presentation/Core/DesignSystem`), `KeychainManager` (en le passant en `actor` et en ajoutant `kSecAttrAccessible`), le moteur `SyncTask` à dépendances (réécrit en `ModelActor`), les routes typées du `AppRouter`, la config xcconfig Dev/Prod. Rien d'autre.

## Points de vigilance connus

- Jamais d'identifiant, mot de passe ou token en dur ni dans les logs : l'ancienne app en avait.
- Un seul `AuthManager` sérialise le refresh de token : l'ancienne app avait quatre chemins de refresh concurrents.
- Isolation mono-tenant **au niveau du contexte**, pas par ligne : les `@Model` ne portent pas de `tenantId`. Le store SwiftData est vidé à la déconnexion **et** au changement de tenant à la connexion (`LocalStore.enforceTenant`, comparant le tenant du jeton au dernier vu ; `LocalStore.erase` efface aussi les marqueurs rangés en UserDefaults, comme le curseur de sync des clients). `VersionedSchema` reste requis dès la V1. L'ancienne app mélangeait les tenants et n'avait pas de migration.
