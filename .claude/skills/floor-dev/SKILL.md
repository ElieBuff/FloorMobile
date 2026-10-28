---
name: floor-dev
description: Conventions de développement pour l'app iOS FloorMobile. À invoquer pour TOUTE création ou modification de code Swift/SwiftUI dans ce projet — nouvelle feature, vue, modèle, écran, navigation, persistance, réseau, authentification. Encode l'architecture Apple Model-View + SwiftData et la configuration Zitadel de l'app. À consulter avant d'écrire du code pour respecter le pattern.
---

# Développement FloorMobile

App iOS native **SwiftUI** de clienteling retail (clients, produits, agenda, messagerie temps réel), cliente de la plateforme Floor (`FloorPlatform`). Réécriture from-scratch de l'ancienne app EmeriaMobile, qui était en Clean Architecture MVVM. Le plan complet est dans [ARCHITECTURE-CIBLE.md](../../../ARCHITECTURE-CIBLE.md) à la racine du projet ; ce skill en est le résumé opérationnel.

## Architecture : Model-View (pas de MVVM)

Suivre les recommandations Apple ([Managing model data](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app), WWDC 2023 "Discover Observation").

- **Pas de ViewModel par écran.** L'état d'écran vit en `@State` dans la vue. La logique métier vit dans les modèles.
- **Un type d'état d'écran (`@Observable` tenu en `@State`, ex. `TaskActions`) n'existe que s'il est partagé par plusieurs vues ou s'il porte une logique que SwiftUI ne fournit pas.** Sinon l'état vit en `@State` dans la vue, avec les outils natifs : `.task(id:)` relance et annule seul quand sa valeur change (recherche pendant la frappe : un `Task.sleep` en tête suffit comme anti-rebond), `.searchable` pour la recherche, `ContentUnavailableView` pour le vide. Avant de proposer un nouveau type, écrire quelle API native couvre le besoin et pourquoi elle ne suffit pas.
- **Organisation par feature** : `Features/<Feature>/` contient tout ce qui parle le vocabulaire de la feature, en **trois dossiers et pas un de plus** — `Data/` (endpoint et service à sa racine, types wire dans `Data/Wire/` : le fil), `Models/` (ce que la donnée *est*, et toute la logique testable sans vue) et `Views/`. Seule exception, deux entités distinctes dans une même feature : voir plus bas. Pas de ViewModels, pas de dossiers par couche à la racine du projet.
- **Deux sous-dossiers de `Models/`**, à créer dès que le dossier dépasse la demi-douzaine de fichiers :
  - `Models/Enums/` — les ensembles ouverts du serveur (`Reason`, `MeetingType`, `EventStatus`) et les clés `EnumValue.Key` qui les nomment. Ils sont là parce que l'API les impose, pas parce que l'app les a choisis. Même nom que `Core/Enums/`, qui porte la machinerie partagée : un concept, un mot — celui du bloc `enums` de `GET setup`.
  - `Models/Drafts/` — ce que l'utilisateur est en train de composer (`EventDraft`, `TaskDraft`) : des value types portant leurs règles de validation, testables sans vue. **Dans** `Models/` et non à côté, parce que « Model » en Model-View veut dire « tout ce qui n'est pas une vue », pas « entité persistée ».
- Une feature qui n'a encore qu'un écran garde quand même son `Views/` (`Features/Home/Views/HomeView.swift`) : le dossier attend la suite, et une feature se lit toujours de la même manière.
- **Une feature qui porte deux entités distinctes les isole chacune dans son sous-dossier**, lui-même en trois dossiers, et ce qui sert les deux reste à la racine de la feature. `Features/Agenda/` en est le premier cas : `Events/{Data,Models,Views}`, `Tasks/{Data,Models,Views}`, et à la racine les huit fichiers réellement communs — `AgendaEndpoint`, `AgendaService`, `Reason`, `EnumValueKey+Agenda`, `AgendaView`, `ReasonIcon`, les deux pickers. Les tests suivent (`FloorMobileTests/Agenda/{Events,Tasks}/`).
  - `Features/Clients/` est le second : `Directory/{Data,Models,Views}` — le répertoire des clients : `Client`, `RecentClient`, la fiche, les deux listes, `ClientsView`, `ClientEndpoint` et `ClientService` — et `SearchOptions/{Data,Models,Views}` — le tri et les filtres de « My Clients » : le catalogue du tenant (`ClientSort`, `ClientFilter`, venus de `GET setup`) et la sélection du vendeur (`ClientSearchOptions`, `ClientFilterChoice`), avec leurs wires, `ClientSearchControls` et ses pickers (« Sort by », « Filter » et son calendrier). Rien à la racine : `SearchOptions` sert `Directory`, qui ne lui prête que de quoi compter — « Filter » compte par `ClientService.countClients`, dans le `ClientSearchScope` de la liste qui l'ouvre (décision du 27/10). Aucun autre fichier ne sert les deux. Le dossier porte le nom de ce qu'il contient, jamais « General » ou « Common ». Les tests suivent (`FloorMobileTests/Clients/{Directory,SearchOptions}/`).
  - Le seuil n'est pas le nombre de fichiers mais le **vocabulaire** : une tâche et un rendez-vous n'ont ni le même statut, ni le même brouillon, ni la même rangée, ni la même route — 24 fichiers sur 33 ne parlaient qu'à l'un des deux, et `Views/Components/` mélangeait `EventRow` et `TaskRow` sans qu'on sache de quel objet on parlait.
  - Ce n'est **pas** une porte ouverte à un dossier par écran ou par cas d'usage, et ce ne sont pas deux features : `AgendaView` affiche les deux, `AgendaService` synchronise les deux. Deux features sœurs obligeraient l'une à importer les vues de l'autre.
- **Socle partagé** dans `Core/` : Networking (dont `Networking/Wire/` pour les fragments wire réutilisés par plusieurs endpoints, ex. `StoreWire`), Auth, Persistence (schéma versionné `FloorSchemaV1` + plan de migration), Enums (`EnumValue`, le vocabulaire), Setup (`Data/` pour `GET setup` : `SetupService` range le vocabulaire, les filtres et les tris du tenant), Realtime, Sync. `Persistence/ModelSync.swift` porte les trois façons de ranger ce que le serveur envoie : `upsert` (des pages qui s'ajoutent), `refresh` (marquage et balayage, pour une liste servie en pages) et `replace` (un ensemble reçu entier, réécrit seulement s'il a changé : le modèle adopte `ContentComparable`).
- **Design system** dans `DesignSystem/`, **un dossier par composant nommé d'après lui** (`AppHeader/`, `FloorAlert/`, `CollapsibleCalendar/`…), y compris les pièces qui ne servent qu'à lui : `CalendarReveal` et `CalendarRowSettle` vivent dans `CollapsibleCalendar/`. Deux dossiers de famille seulement — `Tokens/` et `Forms/`.
- **`DesignSystem/Motion/`** accueille le mouvement **qui ne sait pas quel composant l'appelle** (`BreathingDot`, `SpecularSweep`). Si le nom du type contient celui d'un composant, il reste avec le composant. Passé la demi-douzaine de fichiers, le dossier sert de débarras et il faut le rouvrir.
- **Interdits, même si l'ancien code en avait :** UseCases, Repository protocole + impl, DataSources génériques, DTOs systématiques, containers de DI, singletons `.shared`.

## Flux de données : quel outil choisir

| Besoin | Outil | Persiste au redémarrage |
|---|---|---|
| État local d'une vue | `@State` | non |
| État partagé en RAM (session, utilisateur, tenant, sélection) | classe `@Observable` injectée par `.environment(...)` | non |
| Binding vers un modèle observable | `@Bindable` | — |
| Donnée de référence / offline (source de vérité) | SwiftData `@Model` lu par `@Query` | oui |
| Écriture / import / sync en arrière-plan | `ModelActor` | — |
| Secrets (tokens) | Keychain | oui |

Règles :
- Un `@Observable` partagé est injecté à la racine via `.environment(...)` et lu via `@Environment(Type.self)`. Pas de `EnvironmentKey` avec une `defaultValue` qui construit un objet : une valeur manquante doit se voir, pas être remplacée en silence.
- SwiftData est **local-first** : la vue lit via `@Query`, un Service synchronise l'API en arrière-plan via un `ModelActor`, qui appelle `save()`.
- **Isolation mono-tenant au niveau du contexte, pas par ligne** : les `@Model` ne portent pas de `tenantId`. Le store est vidé à la déconnexion **et** au changement de tenant à la connexion (`LocalStore`). Tout marqueur qui décrit le contenu du store (curseur de sync…) est un `StoredValue` porté par `LocalStore`, pour partir avec les lignes au wipe. Le schéma est déclaré dans un `VersionedSchema` dès la première version.
- Un calcul métier est une propriété calculée du modèle. On ne stocke un résultat que si un ralentissement mesuré le justifie.
- **Forme d'un `@Model`** (et de lui seul) : le corps de la classe ne porte que les **champs stockés et l'`init`** — ce que l'objet *est*, ce que SwiftData persiste. Tout le comportement va dans **une `nonisolated extension` du même fichier**, juste en dessous, découpée par `// MARK: -` (`Sync` pour `stale(token:)`, `Typed views`, `Display`, `Time`…). Pas de fichier `Type+Qualificatif.swift` pour un modèle qui appartient à la feature : ce suffixe est réservé à l'extension d'un type défini ailleurs (`Date+NextHour`, `EnumValueKey+Agenda`). Une règle qui juge **un** objet (`event.standing(at:)`, `event.progress(at:)`) ou choisit parmi **des** objets du même type (`AgendaEvent.next(in:at:)`) vit dans cette extension, pas dans un type utilitaire nommé d'après un écran. Cette règle tient à SwiftData, qui persiste ce que porte le corps de la classe : une simple struct (valeur, résumé, type wire) garde ses propriétés calculées dans son propre corps.
- **Wire → modèle → vue, sans exception.** Ce que le serveur envoie est décodé dans un type wire (`Data/Wire/`), converti en modèle local par un `init(wire:)`, et les vues ne voient que le modèle. Jamais un modèle (`@Model`, résumé, valeur) décodé directement depuis le JSON, même quand les formes coïncident : un renommage côté serveur doit s'arrêter à `init(wire:)`. Les résumés stockés en attribut composite (`ClientSummary`, `SalesAssociateSummary`…) restent `Codable`, mais pour SwiftData, pas pour le réseau. Vaut aussi pour ce qui n'est pas stocké : un résultat de recherche est converti en valeur (`ClientItem`), et un service renvoie des modèles, pas un `CursorPage` de types wire.
- **Un fichier wire par modèle local** : `<Modèle>Wire.swift` dans `Data/Wire/`, qui déclare un `enum <Modèle>Wire` servant d'espace de noms et regroupe **toutes les formes sous lesquelles ce modèle circule**, plus son `init(wire:)`. Le découpage suit le modèle local, pas la route ni la ressource serveur : `Client` (`client/sync`), `ClientProfile` (`client/{id}`) et `RecentClient` (`client/recent`) passent tous par `/client` mais ont chacun leur fichier (`ClientWire`, `ClientProfileWire`, `RecentClientWire`). Un modèle construit sur la `Response` d'un autre n'a pas de fichier wire : son `init(wire:)` vit dans son propre fichier, comme pour un fragment partagé (`ClientItem.init(wire:)`, dans `ClientItem.swift`, lit `ClientWire.Response`).
- **Nommage des types wire** : `Response` (ce que le serveur renvoie) et, si l'app écrit, `Request` (ce qu'elle envoie) — ex. `EventWire.Response` / `EventWire.Request`, les deux sens du même modèle. **Deux types, jamais un seul `Codable`** : la lecture porte des champs possédés par le serveur (`id`, dates, objets imbriqués) que les schémas stricts d'écriture rejettent, et un `nil` n'y a pas le même sens (« le serveur n'a rien » contre « ne pas envoyer la clé »). Une réponse annexe propre au modèle garde un nom qui dit ce qu'elle est (`ClientWire.StoreIDs`).
- **Fragments wire partagés** : un objet que plusieurs réponses embarquent sans endpoint propre est un simple struct `<Chose>Wire` dans `Core/Networking/Wire/` (`StoreWire`, `ClientSummaryWire`, `SalesAssociateWire`), converti par un `init(wire:)` défini dans le fichier du modèle cible (`StoreSummary.init(wire:)`). Côté serveur, chacun répond à une projection partagée de `@floor/types` (`STORE_SUMMARY_SELECT`, `CLIENT_SUMMARY_SELECT`, `SALES_ASSOCIATE_SUMMARY_SELECT`), la même dans toutes les réponses qui l'embarquent — sauf la fiche client (`client/{id}`, renvoyée telle que `getClientById` la lit), dont la boutique ne porte que `storeCode` et `name`, et dont le vendeur est recopié en ligne. Champs optionnels quand le serveur peut ne pas les envoyer (les dépenses d'un client, `metrics`, restent `null` tant qu'il ne les a pas calculées) ; une forme vraiment plus riche a son propre type plutôt que de faire grossir le fragment.

## Réseau

- **URLSession async/await**, un `APIClient` léger dans `Core/Networking`. Les dépendances SPM sont autorisées quand elles apportent une vraie valeur ajoutée, au cas par cas ; ne pas ajouter celles qui n'en apportent pas face aux APIs natives (Alamofire, PopupView, WrappingHStack, swiftui-introspect). Socket.IO est prévue, isolée derrière `RealtimeService`.
- Un **Service par feature** (`ClientService`, `ActivityService`...), struct de closures ou classe, injecté par `init` pour rester testable.
- Erreurs : une seule taxonomie `AppError` avec message utilisateur. Pas de `try?` sur un appel dont l'échec doit être visible.

## Authentification : Zitadel, OIDC natif

L'app se connecte directement à Zitadel, pas à un endpoint `/login` maison.

| Élément | Valeur |
|---|---|
| Issuer | `https://dev-q7qkap.eu1.zitadel.cloud` |
| Application | "Floor Mobile - Dev", type Native, projet Floor (id `378848396062002729`) |
| Client ID | `389695826299033234` |
| Flux | Authorization Code + **PKCE**, sans secret, refresh token activé |
| Redirect / post-logout | `floormobile://auth/callback` / `floormobile://auth/logout` |
| Scopes | `openid profile email offline_access urn:zitadel:iam:org:project:id:378848396062002729:aud` |
| Access token | JWT, rôles inclus ; le backend le valide via JWKS |

- Utiliser `ASWebAuthenticationSession`. Le schéma `floormobile` est déclaré dans `CFBundleURLTypes`.
- **Un seul client ID pour tous les tenants.** Zitadel résout l'organisation de l'utilisateur ; l'app lit le tenant dans le jeton et le stocke dans la session. Ne jamais demander le tenant à l'utilisateur.
- `AuthManager` est un `actor` : un seul refresh en vol à la fois, les appels concurrents attendent le même résultat. Tokens dans le Keychain avec `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Zitadel rotate les refresh tokens** : chaque refresh renvoie un nouveau refresh token qui invalide l'ancien. Persister le nouveau dans le Keychain **avant** de considérer le refresh réussi, sinon un crash au mauvais moment déconnecte l'utilisateur.
- **Marge d'expiration** : `validToken()` considère un access token périmé ~60 s avant son échéance réelle, pour ne jamais envoyer un token qui expire en vol.
- La requête d'autorisation inclut **`state` et `nonce`**, tous deux générés aléatoirement et vérifiés au retour : `state` sur le callback, `nonce` dans l'ID token (obligatoire puisque les claims sont lus sans validation de signature).
- `ASWebAuthenticationSession` avec **`prefersEphemeralWebBrowserSession = true`** : session web isolée, pas de cookies partagés avec Safari. Les appareils peuvent être partagés entre vendeurs en boutique — un logout doit être un vrai logout, et un login doit toujours redemander les identifiants.
- Jamais de token, mot de passe ou corps de réponse d'auth dans les logs. `Logger` avec `privacy: .private` sur toute donnée utilisateur.

## Conventions Swift / SwiftUI

- Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (déjà actif) : ne marquer `nonisolated` ou `actor` que ce qui doit quitter le main thread.
- `async/await` partout, pas de Combine ni de DispatchQueue.
- Design system via tokens (`AppColor`, `AppFont`, `AppSpacing`, `AppRadius`). `AppFont` utilise des tailles relatives (Dynamic Type). Tout bouton icône a un `accessibilityLabel`.
- API modernes : `foregroundStyle`, `clipShape`, `glassEffect` (iOS 26), `NavigationStack(path:)`, `onChange(of:) { old, new in }`.
- Localisation : String Catalog `Localizable.xcstrings`, FR + EN. Aucune chaîne user-facing en dur.
- **Nommage protocole/implémentation** : le protocole porte le nom nu, sans suffixe (`TokenStore` pour un rôle ; participe en *-ing* pour une capacité : `WebAuthenticating`). L'implémentation = qualificatif technique + nom du protocole (`KeychainTokenStore`, `InMemoryTokenStore`) ; pour un protocole en *-ing*, l'implémentation canonique prend la forme agent (`WebAuthenticator`), les autres se qualifient (`StubWebAuthenticator`). Doubles de test : `InMemory…`/`Fake…` = implémentation simplifiée complète, `Stub…` = réponses préprogrammées, `Mock…` = enregistre les appels pour vérification.
- Un type par fichier. Fichiers Swift dans `FloorMobile/`, jamais à la racine du dépôt.
- **Fichier de preview** (décision du 26/10) : un fichier qui ne sert qu'aux previews (un `PreviewModifier` et ses données) porte le préfixe `Preview_` (`Preview_SearchOptionsSampleData.swift`). Son type garde un nom Swift sans soulignement ; les `#Preview` d'une vue restent en bas de son fichier.
- **Ordre d'un fichier** (décision du 26/10, la même que FloorPlatform) : les constantes en tête — les `static let` et les propriétés stockées d'un type en tête de son corps, les constantes privées d'un fichier sous les imports, jamais entre deux fonctions. Sauf les entrées d'un catalogue : un `Endpoint` en `static let` est une route, rangé à côté des routes qui vont avec. Code nouveau et tout fichier touché ; le reste suit au fil des modifications.

## Avant de coder

1. Identifier la feature → travailler dans son dossier, ou dans `Core/` si c'est du socle.
2. **Faire l'inventaire de l'existant** : avant de créer une vue, un composant ou une extension, vérifier qu'il n'existe pas déjà dans `DesignSystem/`, `Core/Extensions/` ou `Features/*/Views/Components/`. Partir de ce que l'app fait déjà.
3. **Tout élément utilisable plusieurs fois est un composant réutilisable** (barre de recherche, avatar, rangée…) : dans `DesignSystem/<Composant>/` s'il ne parle pas le vocabulaire d'une feature, dans `Features/<Feature>/Views/Components/` sinon. Si un composant existant fait presque l'affaire, l'extraire ou le paramétrer (ex. `AppAvatar` → `InitialsAvatar`) plutôt que le recopier.
4. Choisir l'outil de flux de données via le tableau.
5. Tout nouveau `@Model`, `@Observable` ou Service arrive avec ses tests : voir le skill `swiftui-testing`.
6. Vérifier que le résultat compile en lançant le build, pas seulement en relisant. Le code doit être très propre : pas de duplication, pas de code mort, des noms qui disent ce que fait la chose.
