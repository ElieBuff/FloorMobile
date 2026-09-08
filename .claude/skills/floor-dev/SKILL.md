---
name: floor-dev
description: Conventions de développement pour l'app iOS FloorMobile. À invoquer pour TOUTE création ou modification de code Swift/SwiftUI dans ce projet — nouvelle feature, vue, modèle, écran, navigation, persistance, réseau, authentification. Encode l'architecture Apple Model-View + SwiftData et la configuration Zitadel de l'app. À consulter avant d'écrire du code pour respecter le pattern.
---

# Développement FloorMobile

App iOS native **SwiftUI** de clienteling retail (clients, produits, agenda, messagerie temps réel), cliente de la plateforme Floor (`FloorPlatform`). Réécriture from-scratch de l'ancienne app EmeriaMobile, qui était en Clean Architecture MVVM. Le plan complet est dans [ARCHITECTURE-CIBLE.md](../../../ARCHITECTURE-CIBLE.md) à la racine du projet ; ce skill en est le résumé opérationnel.

## Architecture : Model-View (pas de MVVM)

Suivre les recommandations Apple ([Managing model data](https://developer.apple.com/documentation/SwiftUI/Managing-model-data-in-your-app), WWDC 2023 "Discover Observation").

- **Pas de ViewModel par écran.** L'état d'écran vit en `@State` dans la vue. La logique métier vit dans les modèles.
- **Organisation par feature** : `Features/<Feature>/` contient ses vues, ses modèles et son Service. Pas de sous-dossiers View/ViewModel/Store/DTO.
- **Socle partagé** dans `Core/` : Networking, Auth, Persistence, Realtime, Sync. Design system dans `DesignSystem/`.
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
- **Chaque `@Model` porte un `tenantId`** et le schéma est déclaré dans un `VersionedSchema` dès la première version. Une déconnexion vide le store.
- Un calcul métier est une propriété calculée du modèle. On ne stocke un résultat que si un ralentissement mesuré le justifie.
- **DTO seulement si l'API est tordue.** Sinon décoder directement dans le `@Model` ou un struct `Codable`.

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

## Avant de coder

1. Identifier la feature → travailler dans son dossier, ou dans `Core/` si c'est du socle.
2. Choisir l'outil de flux de données via le tableau.
3. Tout nouveau `@Model`, `@Observable` ou Service arrive avec ses tests : voir le skill `swiftui-testing`.
4. Vérifier que le résultat compile en lançant le build, pas seulement en relisant.
