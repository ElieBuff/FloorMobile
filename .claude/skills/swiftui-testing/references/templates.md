# Templates de test — app Floor

Extraits prêts à copier. Les trois helpers (`Support/`) se copient une seule fois dans le test target ; les suites servent de modèle par type de code testé. Remplacer `Floor_Dev` par la valeur de `PRODUCT_MODULE_NAME` du scheme utilisé.

Sommaire :
1. [Support/TestBundleToken + Fixture](#1-fixtures)
2. [Support/ModelContainer en mémoire](#2-swiftdata-en-mémoire)
3. [Support/MockURLProtocol](#3-mockurlprotocol)
4. [Suite : logique d'un @Model](#4-suite--logique-dun-model)
5. [Suite : store @Observable avec service fake](#5-suite--store-observable)
6. [Suite : service réseau et décodage](#6-suite--service-réseau)
7. [Suite : ModelActor d'import](#7-suite--modelactor)
8. [Suite : store de tokens sans Keychain](#8-tokens-sans-keychain)
9. [UI test minimal (XCTest)](#9-ui-test-xctest)

---

## 1. Fixtures

```swift
// <App>Tests/Support/Fixture.swift
import Foundation

/// `Bundle.main` is the host app in an app test target; this token resolves the test bundle.
private final class TestBundleToken {}

enum Fixture {
    static func data(_ name: String, ext: String = "json") throws -> Data {
        let bundle = Bundle(for: TestBundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw FixtureError.notFound("\(name).\(ext)")
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String,
                                     decoder: JSONDecoder = .init()) throws -> T {
        try decoder.decode(type, from: data(name))
    }

    enum FixtureError: Error { case notFound(String) }
}
```

Les fichiers JSON vont dans `<App>Tests/Fixtures/` et doivent apparaître dans le test target (vérifier le membership dans Xcode si le dossier n'est pas un groupe synchronisé).

## 2. SwiftData en mémoire

```swift
// <App>Tests/Support/ModelContainer+Testing.swift
import SwiftData

extension ModelContainer {
    /// One isolated in-memory container per test. Pass only the models the test needs.
    @MainActor
    static func inMemory(for types: any PersistentModel.Type...) throws -> ModelContainer {
        let schema = Schema(types)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

## 3. MockURLProtocol

```swift
// <App>Tests/Support/MockURLProtocol.swift
import Foundation

/// Intercepts every request of a URLSession configured with `protocolClasses = [MockURLProtocol.self]`.
final class MockURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    /// Set per test. Reset to nil in `deinit` of the suite if suites run in parallel.
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    /// Session that never reaches the network.
    static func mocked() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

extension HTTPURLResponse {
    static func ok(_ url: URL, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"])!
    }
}
```

Avec Alamofire, même principe : `Session(configuration: config)` où `config.protocolClasses = [MockURLProtocol.self]`.

Le `static var handler` partagé impose de ne pas faire tourner deux suites réseau en parallèle sur ce global : marquer ces suites `.serialized` ou, mieux, utiliser `.tags(.network)` et une seule suite par service.

## 4. Suite : logique d'un @Model

```swift
import Testing
import Foundation
@testable import Floor_Dev

@Suite("Task model")
struct TaskModelTests {

    @Test("Task is overdue when due date is past and not completed")
    func overdueWhenPastAndOpen() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(title: "Call client", dueDate: now.addingTimeInterval(-3600), isCompleted: false)

        #expect(task.isOverdue(at: now))
    }

    @Test("Completed task is never overdue", arguments: [-3600.0, 0, 3600])
    func completedNeverOverdue(offset: TimeInterval) {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let task = TaskItem(title: "Call client", dueDate: now.addingTimeInterval(offset), isCompleted: true)

        #expect(!task.isOverdue(at: now))
    }
}
```

La date est injectée (`at:`) : un `Date()` dans le modèle rendrait ce test non reproductible.

## 5. Suite : store @Observable

Le store reçoit une struct de closures ; le test la remplace sans écrire de classe fake.

```swift
// Dans l'app
struct ClientService {
    var fetchAll: () async throws -> [Client]
}

@MainActor @Observable
final class ClientStore {
    private(set) var clients: [Client] = []
    private(set) var isLoading = false
    private(set) var lastError: Error?
    private let service: ClientService

    init(service: ClientService) { self.service = service }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do { clients = try await service.fetchAll(); lastError = nil }
        catch { lastError = error }
    }
}
```

```swift
// Dans le test target
import Testing
@testable import Floor_Dev

@MainActor
@Suite("ClientStore")
struct ClientStoreTests {

    @Test("Load fills clients and clears loading state")
    func loadSuccess() async {
        let store = ClientStore(service: .init(fetchAll: { [Client.fixture(name: "Ada")] }))

        await store.load()

        #expect(store.clients.map(\.name) == ["Ada"])
        #expect(store.isLoading == false)
        #expect(store.lastError == nil)
    }

    @Test("Load keeps previous clients and exposes the error on failure")
    func loadFailure() async {
        let store = ClientStore(service: .init(fetchAll: { throw URLError(.notConnectedToInternet) }))

        await store.load()

        #expect(store.clients.isEmpty)
        #expect(store.lastError is URLError)
    }
}
```

`Client.fixture(...)` est une `static func` définie dans le test target (extension) avec des valeurs par défaut, pour ne pas répéter dix arguments dans chaque test.

## 6. Suite : service réseau

```swift
import Testing
import Foundation
@testable import Floor_Dev

@Suite("ClientAPI", .serialized, .tags(.network))
struct ClientAPITests {
    let api = ClientAPI(session: .mocked(), baseURL: URL(string: "https://test.local")!)

    @Test("Decodes a real page of clients")
    func decodesPage() async throws {
        MockURLProtocol.handler = { request in
            (.ok(request.url!), try Fixture.data("clients_page1"))
        }

        let page = try await api.fetchClients(page: 1)

        #expect(page.items.count == 20)
        let first = try #require(page.items.first)
        #expect(first.email == "ada@example.com")
    }

    @Test("Maps 401 to unauthorized error")
    func unauthorized() async {
        MockURLProtocol.handler = { request in (.ok(request.url!, status: 401), Data()) }

        await #expect(throws: NetworkError.unauthorized) {
            try await api.fetchClients(page: 1)
        }
    }
}

extension Tag {
    @Tag static var network: Self
    @Tag static var persistence: Self
}
```

## 7. Suite : ModelActor

```swift
import Testing
import SwiftData
@testable import Floor_Dev

@MainActor
@Suite("ClientImporter", .tags(.persistence))
struct ClientImporterTests {
    let container: ModelContainer

    init() throws {
        container = try .inMemory(for: Client.self)
    }

    @Test("Import upserts by remote id instead of duplicating")
    func upsert() async throws {
        let importer = ClientImporter(modelContainer: container)
        let payload = try Fixture.decode([ClientPayload].self, from: "clients_page1")

        try await importer.importClients(payload)
        try await importer.importClients(payload)   // second run must not duplicate

        let count = try container.mainContext.fetchCount(FetchDescriptor<Client>())
        #expect(count == payload.count)
    }
}
```

Le `ModelActor` doit appeler `modelContext.save()` à la fin de l'import, sinon `mainContext` ne voit rien.

## 8. Tokens sans Keychain

```swift
// Dans l'app
protocol TokenStore: Sendable {
    func read() -> AuthTokens?
    func write(_ tokens: AuthTokens)
    func clear()
}
// KeychainManager: TokenStore   ← conformance ajoutée, code Keychain inchangé
```

```swift
// Dans le test target
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    var tokens: AuthTokens?
    func read() -> AuthTokens? { tokens }
    func write(_ tokens: AuthTokens) { self.tokens = tokens }
    func clear() { tokens = nil }
}
```

Utile en particulier pour tester la **sérialisation du refresh de token** : deux appels concurrents qui reçoivent un 401 doivent produire un seul refresh. Compter les appels dans `MockURLProtocol.handler` et vérifier `== 1`.

## 9. UI test (XCTest)

```swift
import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testAppLaunchesToLogin() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]   // the app can read this to skip animations / use mock data
        app.launch()

        XCTAssertTrue(app.buttons["login.submit"].waitForExistence(timeout: 5))
    }
}
```

Les identifiants d'accessibilité (`.accessibilityIdentifier("login.submit")`) sont posés dans la vue au moment où le test en a besoin, avec un nommage `feature.element`.
