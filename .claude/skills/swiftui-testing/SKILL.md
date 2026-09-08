---
name: swiftui-testing
description: Écrire, organiser et lancer les tests de l'app iOS Floor (SwiftUI, Swift Testing, SwiftData, @Observable). À invoquer dès que l'utilisateur veut ajouter, corriger ou lancer des tests, rendre un modèle ou un service testable, créer des fixtures ou des doubles (mock, stub, fake), mesurer la couverture, ou dès qu'on crée un nouveau @Model, @Observable ou Service — car tout nouveau code métier doit arriver avec ses tests. Couvre aussi les commandes xcodebuild test et le diagnostic d'un test target qui ne compile pas.
---

# Tests de l'app Floor

Le projet est en réécriture vers l'approche Apple **Model-View** (`@Observable` + SwiftData, sans ViewModel) et part de **zéro test**. Ce skill fixe la manière de tester ce nouveau code pour que la couverture grandisse avec la migration, feature par feature. Les conventions d'architecture sont dans le skill `floor-dev` : ce skill ne les répète pas, il dit comment les tester.

## Outils

| Type | Framework | Cible | Quand |
|---|---|---|---|
| Unitaire (modèles, stores, services, décodage) | **Swift Testing** (`import Testing`) | `<App>Tests` | par défaut, pour tout |
| UI de bout en bout | **XCTest** (`XCUIApplication`) | `<App>UITests` | rare : parcours critiques (login, onglet principal) |

Swift Testing ne sait pas piloter `XCUIApplication`, donc XCTest reste obligatoire pour la cible UI. Ne pas écrire de nouveaux tests unitaires en XCTest : `#expect` donne des messages d'échec lisibles sans les écrire soi-même, et les suites `struct` isolent l'état par test.

Pas de bibliothèque tierce d'introspection de vues (ViewInspector, etc.) : on ne teste pas le `body` d'une vue. Dans Model-View, la logique testable vit dans les modèles ; si une vue contient de la logique qu'on a envie de tester, c'est le signal de la déplacer vers un modèle.

## Nom du module à importer

Le nom du module n'est pas le nom du target quand celui-ci contient un tiret : `Floor-Dev` → `Floor_Dev`. Vérifier avant d'écrire le premier `@testable import` :

```bash
xcodebuild -project <App>.xcodeproj -scheme <Scheme> -showBuildSettings 2>/dev/null | grep PRODUCT_MODULE_NAME
```

## Diagnostic d'un test target qui ne tourne pas

Trois pannes reviennent, toutes dans le projet Xcode et jamais dans les tests eux-mêmes. Les vérifier dans cet ordre avant de toucher au code :

| Symptôme | Cause | Correction |
|---|---|---|
| `isn't a member of the specified test plan or scheme` | Le scheme n'a pas de section *Test* avec le target, ou n'est pas partagé (pas de fichier dans `xcshareddata/xcschemes/`) | Xcode ▸ Edit Scheme ▸ Test ▸ ajouter le target, puis Manage Schemes ▸ cocher *Shared* et commiter le `.xcscheme` |
| `No such module 'X'` | `@testable import` utilise le nom du target, pas `PRODUCT_MODULE_NAME` | Importer le nom du module (tiret → underscore) |
| Build OK mais les tests ne se lancent pas, ou `TEST_HOST` cite un `.app` inexistant | `TEST_HOST` / `BUNDLE_LOADER` conservent l'ancien nom de produit après un renommage de target | Aligner `TEST_HOST` sur `$(BUILT_PRODUCTS_DIR)/<FULL_PRODUCT_NAME>/<PRODUCT_NAME>` du target app dont dépend le test target |

Après tout renommage de target, relancer le script de test avant de considérer le renommage terminé.

## Quoi tester, dans l'ordre de valeur

1. **Logique métier des modèles** (`@Model`, structs `Codable`, enums) : calculs, règles, transitions d'état. Fonctions pures, tests rapides, aucun double nécessaire. C'est l'essentiel de la couverture.
2. **Stores `@Observable`** : séquence d'états (`isLoading`, erreur, données) autour d'un appel à un service injecté et remplacé par un fake.
3. **Services / Importers** : décodage des réponses API depuis des fixtures JSON, mapping vers les `@Model`, gestion des erreurs HTTP. Réseau coupé via `URLProtocol`.
4. **Persistance SwiftData** : requêtes (`FetchDescriptor`, prédicats), unicité, import en `ModelActor`, suppression en cascade. Container **en mémoire**, un par test.
5. **UI** : un test de lancement et le parcours de login, pas plus tant que l'app bouge.

## Rendre le code testable sans ViewModel

L'absence de ViewModel n'empêche pas l'injection : c'est le **service** qu'on remplace, pas la vue.

- Un store ou un modèle qui parle au réseau reçoit son service par `init`, typé par un **protocole** ou une **struct de closures**. La struct de closures (`struct ClientService { var fetchAll: () async throws -> [Client] }`) est souvent plus légère qu'un protocole plus une classe fake, et se remplace en une ligne dans un test.
- Ce qui dépend du temps reçoit `now: Date` ou `clock: () -> Date` en paramètre, jamais `Date()` en dur dans la logique.
- Le Keychain n'est jamais touché par un test unitaire : le code qui stocke des tokens dépend d'un protocole (`TokenStore`) dont le test fournit une version en mémoire. Le `KeychainManager` réel est conservé tel quel.
- Un singleton (`.shared`) rend le test impossible à isoler. Le nouveau code ne doit pas en créer ; s'il faut en tester un existant, exposer un `init` interne et l'instancier dans le test.

## Patterns Swift Testing à suivre

Les extraits complets (helper de container, `MockURLProtocol`, chargeur de fixtures, exemples de suites) sont dans [references/templates.md](references/templates.md). Copier ces helpers dans le test target une seule fois, dans `Support/`.

- **Suite = `struct`** avec `@Suite("Nom lisible")`. Chaque test reçoit une instance neuve, donc l'état créé dans `init` est isolé sans `setUp`.
- **Suite `@MainActor`** quand elle teste un store `@MainActor @Observable` : sinon chaque accès demande un `await` et le compilateur se plaint.
- **`#expect`** pour les assertions, **`#require`** pour ce qui doit exister avant de continuer (un optional, un premier élément). Un `#require` échoué arrête le test proprement au lieu de produire un crash sur `!`.
- **Tests paramétrés** `@Test(arguments: [...])` pour les tables de cas (formats, statuts, règles métier). Un cas = un échec identifiable dans Xcode, contrairement à une boucle.
- **`confirmation`** pour vérifier qu'un callback ou une notification est bien émise un nombre exact de fois.
- **`withKnownIssue`** pour un bug connu qu'on ne corrige pas tout de suite : le test reste vert et signale le jour où le bug disparaît.
- **`.tags`** (`.network`, `.persistence`) pour filtrer, **`.serialized`** seulement si des tests partagent une ressource réelle (ils ne devraient pas).
- Vérifier une **erreur précise** avec `#expect(throws: NetworkError.self) { try await ... }`, pas un `do/catch` maison.

## SwiftData en test

- Container en mémoire par test : `ModelConfiguration(isStoredInMemoryOnly: true)`. Le créer dans l'`init` de la suite, le schéma étant la liste explicite des `@Model` concernés (pas le schéma complet de l'app, pour garder le test lisible).
- Lire via `ModelContext` et `FetchDescriptor` : `@Query` est un outil de vue et n'a pas sa place dans un test.
- Tester un `ModelActor` en lui passant le container en mémoire, puis en relisant depuis le `mainContext`. Bien `save()` dans l'acteur, sinon le contexte principal ne voit rien.
- Les contraintes `@Attribute(.unique)` ne se vérifient qu'après `save()` : un test d'unicité qui n'appelle pas `save()` passe à tort.

## Réseau en test

- Bloquer tout réseau réel : `URLSessionConfiguration.ephemeral` avec `protocolClasses = [MockURLProtocol.self]`, injectée dans l'`APIClient`. Le réseau est en URLSession natif (décision actée, voir `floor-dev`).
- Fixtures JSON dans `<App>Tests/Fixtures/`, une par réponse réelle de l'API, nommées `<ressource>_<cas>.json` (`clients_page1.json`, `client_missing_email.json`). Une fixture est copiée d'une vraie réponse, pas inventée : c'est ce qui rend le test de décodage utile.
- Charger les fixtures via `Bundle(for: TestBundleToken.self)` : dans un test target d'app, `Bundle.main` est le bundle de l'app hôte, pas celui des tests.

## Organisation des fichiers

Le test target reflète les features de l'app :

```
<App>Tests/
├── Support/            # helpers partagés : container, MockURLProtocol, Fixture
├── Fixtures/           # JSON de réponses API
├── Clients/
│   ├── ClientTests.swift            # logique du @Model
│   ├── ClientStoreTests.swift       # store @Observable
│   └── ClientServiceTests.swift     # décodage + erreurs HTTP
└── Agenda/
    └── ...
```

Un fichier de test par type testé, nommé `<Type>Tests.swift`. Noms de tests en anglais comme le code, en phrase descriptive : `@Test("Overdue task is flagged when due date is past")`. Le nom doit dire le comportement, pas la méthode appelée.

## Lancer les tests

Le script [scripts/run-tests.sh](scripts/run-tests.sh) détecte le scheme et un simulateur disponible, et accepte un filtre :

```bash
.claude/skills/swiftui-testing/scripts/run-tests.sh                       # tout le test target unitaire
.claude/skills/swiftui-testing/scripts/run-tests.sh Clients/ClientTests     # une suite
.claude/skills/swiftui-testing/scripts/run-tests.sh --ui                    # les UI tests
```

À la main, la forme de base est :

```bash
xcodebuild -project <App>.xcodeproj -scheme <Scheme>-Dev \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:<App>Tests test
```

`-only-testing` accepte `Target`, `Target/Suite` ou `Target/Suite/test`. Le nom du simulateur doit exister dans `xcrun simctl list devices available` : la machine a des iPhone 17, pas d'iPhone 16. La sortie brute de `xcodebuild` est verbeuse ; lire la fin (`Test Suite ... passed/failed`) ou filtrer sur `error:` et `Test Case`.

## Avant de rendre la main

- Tout nouveau `@Model`, `@Observable` ou Service arrive avec au moins un test de sa logique principale et un test d'un cas d'erreur.
- Les tests de la feature touchée passent, lancés avec `-only-testing`. Dire explicitement s'ils n'ont pas été lancés et pourquoi.
- Aucun test ne dépend du réseau, du Keychain ou d'un fichier SwiftData sur disque.
- Les fixtures ajoutées sont référencées dans le test target (Xcode ne les copie pas automatiquement si elles sont hors du dossier synchronisé).
