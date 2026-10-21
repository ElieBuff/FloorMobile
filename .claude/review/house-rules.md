# Review rules — FloorMobile

Read by both reviewers before they review: `plan-critic` (a plan, before the user sees it) and `qa-reviewer` (the
code, once the plan is implemented). One text for both, so that a plan and its code are judged by the same rules; each
agent keeps its own severity scale, rounds and output. Not under `.claude/agents/`, where every file is read as an
agent.

These rules summarize the project's own; the sources stay the reference, and both reviewers read them too:
`.claude/skills/floor-dev/SKILL.md` (architecture, folders, naming), `.claude/skills/swiftui-testing/SKILL.md` (tests)
and, for the sections a change touches, `ARCHITECTURE-CIBLE.md`. Where `ARCHITECTURE-CIBLE.md` and `floor-dev`
disagree, `floor-dev` is the current rule (`ARCHITECTURE-CIBLE.md` still describes DTOs only for a twisted API, a flat
Agenda, GitHub Actions, `.appErrorAlert`: all superseded).

## Architecture and code quality

For every new or moved type, view and function — as a plan describes it, or as the code writes it — judge where it
goes, what it is called, what it owns, and what it depends on. Check each answer against the code (`Glob`/`Grep` the
neighbours), against `floor-dev`, and against Apple's own guidance.

**Native first.** For every new type, the change must be able to say which native API covers the need and why it is
not enough. `.searchable`, `.task(id:)` (it restarts and cancels on its own; a `Task.sleep` at its head debounces),
`@State`, `@Query`, `ContentUnavailableView`, `NavigationStack(path:)`… If the answer is empty, the type should not
exist. A screen-state `@Observable` exists only when several views share it, or when it carries logic SwiftUI does not
provide (`TaskActions` documents why it does). Copying the closest precedent is not a justification.

**The right place.**
- A feature is `Features/<Feature>/{Data,Models,Views}` — three folders, not one more. `Data/` holds the endpoint,
  the service and the wire types; `Models/` what the data *is* and every rule testable without a view (with
  `Models/Enums/` and `Models/Drafts/` past half a dozen files); `Views/` the views (`Components/`, `Sections/`,
  `Details/`, `Pickers/`). Two entities with distinct vocabularies in one feature get a sub-folder each, as
  `Agenda/{Events,Tasks}` does — never one folder per screen. Tests follow the same tree in `FloorMobileTests/`.
- Shared foundations go in `Core/`: `Networking/` (with `Networking/Wire/` for wire fragments several responses
  embed), `Models/` (shared value snapshots: `ClientSummary`, `StoreSummary`…), `Extensions/`, `Auth/`,
  `Persistence/`, `Enums/`, `Sync/`. Components that speak no feature's vocabulary go in `DesignSystem/<Component>/`,
  one folder per component named after it; the only family folders are `Tokens/`, `Fields/` and `Motion/`.
- A rule that judges one object, or chooses among objects of the same type, lives in that model's
  `nonisolated extension`, not in a utility type named after a screen.

**The shape of a `@Model`.** The class body carries only the stored fields and the `init`. Behaviour goes in a
`nonisolated extension` in the same file, just below, split by `// MARK: -`. No `Type+Qualifier.swift` file for a
model the feature owns: that suffix is for extending a type defined elsewhere (`Date+NextHour`). A plain struct (a
value, a summary, a wire type) keeps its computed properties in its own body.

**Wire → model → view, no exception.** Server JSON is decoded into a wire type in `Data/Wire/`, converted by
`init(wire:)`, and views see only the model. One `<Model>Wire.swift` per local model, an `enum` namespace holding
`Response` and, if the app writes, `Request` — two types, never one shared `Codable`. A model built from another
model's `Response` has no wire file: its `init(wire:)` lives in its own file, as for a shared fragment
(`ClientItem.init(wire:)` reads `ClientWire.Response`). A search result that is not stored is converted to a value
(`ClientItem`). A service returns models or values, never a page of wire types.

**Reuse.** Before anything new, inventory `DesignSystem/`, `Core/Extensions/`, `Core/Models/`,
`Features/*/Views/Components/` and the models' extensions, and start from what the app already does.
- **UI.** An element that can serve more than once (a row, an avatar, a search field, a card, a list style) is a
  component from its first use: in `DesignSystem/<Component>/` if it speaks no feature's vocabulary, in
  `Features/<Feature>/Views/Components/` otherwise. One that almost fits is extracted or parameterized
  (`AppAvatar` → `InitialsAvatar`), never copied; a modifier chain that a component already spells (`.cardList()`)
  is used, not re-spelled.
- **Logic** (the user's decision, 2026-10-16). Logic that can serve more than once goes, from its first use, where
  every caller will find it: the model's `nonisolated extension`, a shared value in `Core/Models/`, an extension in
  `Core/Extensions/` — never in a view, never in a helper named after a screen. Duplicated logic is a finding. But no
  speculative abstraction: a protocol, a generic or a parameter only for a real second user ("un protocole seulement
  quand un besoin réel existe", `ARCHITECTURE-CIBLE.md`).

**Dependencies point one way.** Features use `Core/` and `DesignSystem/`; `Core/` and `DesignSystem/` never know a
feature. A feature never imports another feature's views: what two features share moves to `Core/` or
`DesignSystem/`.

**A new local entity** (a `@Model` the app stores) touches, all together: its `@Model` (`Syncable` with
`@Attribute(.unique) var id` and `syncToken` when it is refreshed by mark-and-sweep); its `<Model>Wire.swift` with
`init(wire:)`; an `Endpoint` static func; a service method (`ModelContext.refresh`, `store(_:as:)` for writes);
`FloorSchemaV1.models`; `LocalStore.erase` **and** both lists of `LocalStoreTests` (they are hand-mirrored, nothing
cross-checks them); `AppServices` if it gets a service; the preview containers that list every model
(`RootView.swift`); its trigger — at startup `SyncManager.performSync` **and** a `hasUsableCache` term, or on screen;
a cursor or marker as a `StoredKey` owned by `LocalStore` and reset in `erase`. A missing one is a finding.

**Clean, by Apple's and the industry's standards.**
- One type per file, named for what it is (a tightly coupled companion type may share its file); protocol /
  implementation and test-double naming as `floor-dev` sets it.
- Services injected through `init` (a struct of closures or a protocol), never a `.shared` singleton.
- `async/await` only: no Combine, no `DispatchQueue`. Mark `nonisolated` or `actor` only what must leave the main
  actor (the default isolation is `MainActor`).
- Errors as `AppError` with a user message, shown with `.floorAlert`; no `try?` on a call whose failure must show.
- Forbidden even if EmeriaMobile had them: ViewModels, UseCases, Repository protocol + impl, generic DataSources,
  systematic DTOs, DI containers.
- A small surface, no duplication, no dead code, no "temporary" branch without an owner. Names that say what the
  thing does. Readable beats clever.

**Documented.** The comments are the context the next AI reads before it writes in a file; the code already sets the
standard. Every type and non-trivial function has a `///` comment that says **what** it does, then **why** it is built
so — the measured reason, the known limit, often the alternative that was rejected (`LocalStore.erase`,
`ClientService.synchronize`, `AgendaService.setStatus` show the tone). What must stay in step with something elsewhere
is named (a list mirrored in a test, a rule mirrored from the BFF). A comment the change made false is a defect. No
comment that paraphrases the code, no history ("used to…"). In English, like the code and the names.

**The screen.**
- Every user-facing string in `Localizable.xcstrings`, FR and EN; never hard-coded.
- Colours from the asset catalog's generated symbols (`Color(.Base.ink)`, `Color(.OnSurface.textSecondary)`…), fonts
  as SwiftUI text styles (Dynamic Type), and the `DesignSystem/Tokens/` values (`AppRadius`, `AppShadow`,
  `AppBorder`, `AppSpacing.cardInset`). A number used once stays a literal in the view: `AppSpacing`'s own rule.
- An `accessibilityLabel` on every icon button; empty, loading and error states (`ContentUnavailableView`,
  `EmptySectionCard`).

**Severity here.** IMPORTANT when the problem has a concrete cost: a custom type duplicating a native API, a copied
view or logic that will drift from its original, a model decoded straight from JSON, a dependency in the wrong
direction, logic in a view that should be tested in a model, a new entity missing from one of the places above, a
non-obvious rule left undocumented or a comment made false. SUGGESTION for a better name or a clearer split with no
such cost. In both cases, the evidence is the existing code or the `floor-dev` rule that shows the right way.

## House rules

- **Tenant isolation is at the context level, not per row.** `@Model`s carry no `tenantId`. The store is wiped on
  logout and on a tenant change (`LocalStore.enforceTenant` / `erase`), markers included.
- **The store's shape and existing installs.** The container is built from `FloorSchemaV1` and a migration plan with
  no stage, and a container that fails to open ends in `fatalError` (`FloorMobileApp.swift`): no wipe-and-retry. Any
  change to the on-disk shape — a `@Model` stored property (added, removed, renamed, retyped, made unique), the
  `FloorSchemaV1.models` list, the fields of a composite snapshot stored in a model (`ClientSummary`…), a `StoredKey`
  raw value — must say how an existing install (TestFlight Staging included) opens the new store: a change SwiftData
  migrates on its own, or a new `VersionedSchema` with a migration stage, or an explicit wipe. Silence is a finding.
- **Secrets.** No token, password or auth response body in code or logs. `Logger` with `privacy: .private` on any
  user data. Tokens in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), one `AuthManager` actor.
- **The BFF decides, the app renders.** Logic and values fixed for a screen live in the `mobile/bff` controller
  (`../FloorPlatform/floor/mobile/bff`); the app does not send filter parameters the server should hard-code.
- **The server contract, field by field.** The BFF routes declare their responses as `z.any()`: the real shape is the
  select in `../FloorPlatform/floor/packages/types/src/select/*.select.ts`, and write bodies are the strict schemas in
  `../FloorPlatform/floor/packages/types/src/schemas/`. A wire type is checked against those, not against the route.
  Fixtures are copied from real responses, never invented. A change that needs the server to change says so and
  names the change.
- **Client search.** The server searches, typos and all. "My Clients" asks `client/search?scope=mine` from
  `Endpoint.clientSearchMinimumLength` characters, interactive (`Endpoint.interactive`), and searches the device's copy
  below that and when the server does not answer (`Client.matching`, a plain `localizedStandardContains` predicate,
  `fetchLimit` grown by pages); "All Brand" asks `client/search`. Both server lists go through `PagedSearchList`. The
  device does not reimplement the server's rules: a future search on the device follows them (`floor_search_fold`, the
  shared vectors in `../FloorPlatform/floor/packages/domain/test/client-search.vectors.json`), never invents its own.
- **SPM dependencies** only with a real added value over the native APIs.
- **Swift files live in `FloorMobile/`**, never at the root of the repository.

## Plausible cases, not extreme ones

Every branch written for an edge case brings its code, its tests and its own edge cases.

- A rare combination whose damage is **limited** — it fixes itself at the next sync, a value shows stale until the
  next refresh, the associate corrects it on screen — is at most a SUGGESTION: "document it in one line".
- The damage is **not limited** when it loses user input, shows another tenant's data, leaves the local store
  durably wrong, crashes (at launch included), or loops network calls. That can be BLOQUANT or IMPORTANT.
