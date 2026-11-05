---
name: release
description: Livrer FloorMobile — Xcode Cloud, rituel de release prod, et la liste des prérequis (BFF de staging, migrations, schéma SwiftData) à vérifier avant de merger develop sur main ou de poser un tag v*. À ouvrir avant tout merge sur main, tout tag v*, et chaque fois qu'une fonctionnalité ajoute un prérequis serveur (il s'ajoute ici).
---

# Livrer FloorMobile

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

**Avant de merger `develop` sur `main`** (livraison staging) :
- l'app doit élaguer ses clients par `GET client/my-ids` et non plus `client/store-ids` (`Endpoint.storeClientIDs`, `ClientService.pruneDeparted`) : FloorPlatform `aec5fa1`, déjà sur son `main`, retire `store-ids` (un 404). Sinon, dès qu'un BFF avec `aec5fa1` est déployé, l'élagage échoue à chaque lancement et les clients partis restent sur l'appareil ;
- le BFF de staging doit servir :
  - `client/search?scope=mine` (FloorPlatform `a588a6f`, migrations `20261014114005` et `20261016033543` en fenêtre de maintenance). Sinon, « My Clients » liste toute la marque sans erreur ;
  - la synchro des clients en carte « mine », avec la boutique et les mots de recherche (FloorPlatform `3cbdfa7`). Sinon, elle range sans erreur des clients sans le nom de leur boutique, ou sans mots de recherche, qui ne se corrigent qu'au prochain changement de chacun, ou d'un coup par une synchro complète (déconnexion ou réinstallation) ;
  - `GET client/recent`, `POST client/{id}/view` (qui renvoie la liste des récents) et `GET client/{id}` (FloorPlatform `64369b1` et `3cbdfa7`, migration `20261019082534_client_views`). Sinon, la fiche client ne s'ouvre pas, et les récents restent vides (sans bloquer le démarrage) ;
  - `GET setup` avec ses blocs `enums`, `clients.filters`, `clients.sorts` et `salesAssociate` (`preferredLanguage`) (FloorPlatform `fa222f1`, `a18a187`, `52067b4` et `e003bba`, migration `20261020111949_client_filters`). Sinon, le lancement échoue sans cache, et un appareil qui en a un garde l'ancien vocabulaire, sans filtres, tris ni langue. Les filtres d'un tenant s'écrivent avec `pnpm seed:client-filters <tenantId>` (console API) : sans eux, le bloc arrive vide, sans rien bloquer ;
  - `GET client/count` (FloorPlatform `cf5762b`, branche `feat/client-count`, pas encore sur son `main`). Sinon, la feuille « Filter » ne montre pas son nombre de clients, sans erreur ;
  - la nouvelle forme de `GET client/{id}` (`getClientProfile` : `email`, `mobile`, `optins`, `mainAddress`, le vendeur et le magasin en projections partagées, et `segment`, que le serveur doit encore ajouter), `GET client/{id}/summary` (le chemin, plus `/client/summary/{id}`) et `GET client/{id}/timeline`. Au 04/11, rien n'est commité côté FloorPlatform : noter ici le commit une fois fait. Sinon, la fiche ne s'ouvre plus (`optins` manque au décodage), et le résumé IA et la timeline répondent 404 ; sans `segment`, l'en-tête de la fiche montre celui de la liste puis l'efface à l'arrivée des détails (ouverte par un lien, il n'en montre aucun), sans erreur ;
  - `POST client/text-filters`, et les filtres d'une phrase (`{ "filter": … }`) dans `client/search` et `client/count` : le BFF, `intelligence` et `ai_engine` à FloorPlatform `18d34a8` ou après (les routes `346a1ae`, l'agent `3b17cb1` et `090ac4a`), le prompt Langfuse `client-query` étiqueté `production`, après son golden ×3 (`090ac4a` ne l'étiquette que `dev`, et le staging comme la prod lisent `production`), et la migration `20261023042903_purchase_filter_indexes` (`5a36d42`) passée services arrêtés, puis `VACUUM (ANALYZE) crm_transactions`. Sinon, une phrase ne se lit pas (« Couldn't read the sentence. Try again. »), ou, sans `18d34a8`, « My Clients » affiche « Search failed » dès qu'une pastille est appliquée ; rien d'autre n'est bloqué ;
- `a18a187` retire `/enums` sans alias, et l'app livrée sur `main` l'appelle encore : le BFF de staging et le merge sur `main` partent ensemble (de même en prod, BFF et tag `v*`). Un BFF déployé avant laisse bloqué au lancement tout testeur qui se déconnecte ou réinstalle ;
- `3cbdfa7` applique aussi `20261018195148_drop_unused_client_indexes`, à passer services arrêtés ou dans un moment calme : chaque `DROP INDEX` verrouille `crm_clients` un instant. Le code tourne avec ou sans ces index ;
- `FloorSchemaV2` doit exister : V1 redevient exactement la forme livrée sur `main` (`eccdb89` : `AIAction`, `AgendaEvent` et `AgendaTask` avec `reasonRaw` non optionnel, `FieldOption`), V2 porte la forme actuelle, `Client`, `ClientFilter`, `ClientSort`, `RecentClient` et `EnumValue` (l'ancien `FieldOption`, rechargé à chaque lancement) compris, avec une étape de migration de V1 à V2. L'étape laisse `EnumValue` vide : un premier lancement hors ligne après la mise à jour reste sur l'écran de chargement jusqu'au retour du réseau, sauf si elle recopie `FieldOption` dans `EnumValue`.

À faire avant une vraie prod : remplacer les placeholders Zitadel de `Staging.xcconfig`/`Prod.xcconfig` (TODO dans les fichiers), domaine `login.staging.floorapp.ai`/`login.floorapp.ai`, branding de la page de login Zitadel.
