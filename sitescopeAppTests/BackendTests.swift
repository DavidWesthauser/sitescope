import XCTest

#if canImport(sitescopeCore)
    @testable import sitescopeCore
#else
    @testable import sitescope
#endif

final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.handler!(request)
            client?.urlProtocol(
                self,
                didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!,
                cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@MainActor final class BackendTests: XCTestCase {
    func backend(_ handler: @escaping (URLRequest) throws -> (Int, Data)) -> Backend {
        StubProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return Backend(
            config: Configuration(url: URL(string: "https://fixture.invalid")!, key: "public-fixture"),
            urlSession: URLSession(configuration: config), persistSession: false)
    }
    func authData() throws -> Data {
        try JSONEncoder().encode(
            AuthSession(
                access_token: "fixture-access", refresh_token: "fixture-refresh",
                expires_at: Date().timeIntervalSince1970 + 3600, user: User(id: UUID(), email: "fixture@example.test")))
    }
    func testLoginAndAuthorizedProjectLoad() async throws {
        let auth = try authData()
        let project = Project(name: "Shared apartment", responsible_id: UUID())
        // A real `projects` row; columns the app does not show are ignored.
        let data = Data(
            """
            [{"id":"\(project.id)","name":"Shared apartment","responsible_id":"\(project.responsible_id!)",
              "created_by":null,"created_by_org":null,"created_at":"2026-11-27T12:00:00Z"}]
            """.utf8)
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-fixture")
            return (200, data)
        }
        let loggedIn = try await backend.authenticate(
            email: "fixture@example.test", password: "password", register: false)
        XCTAssertTrue(loggedIn)
        let store = Store(backend: backend)
        try await store.loadProjects()
        XCTAssertTrue(store.signedIn)
        XCTAssertEqual(store.projects, [project])
    }
    func testOfflineLoadPreservesPreviousProjects() async throws {
        let auth = try authData()
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            throw URLError(.notConnectedToInternet)
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        let store = Store(backend: backend)
        let old = Project(name: "Keep visible")
        store.projects = [old]
        do {
            try await store.loadProjects()
            XCTFail("Expected offline error")
        } catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        XCTAssertEqual(store.projects, [old])
    }
    func testUnconfirmedRegistrationDoesNotCreateLogin() async throws {
        let backend = backend { _ in (200, Data("{\"user\":{}}".utf8)) }
        let active = try await backend.authenticate(email: "new@example.test", password: "password", register: true)
        XCTAssertFalse(active)
        XCTAssertNil(backend.user)
    }
    func testPermissionErrorAndEmptyMutationAreReported() async throws {
        let auth = try authData()
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            if request.httpMethod == "PATCH" { return (200, Data("[]".utf8)) }
            return (403, Data("{\"message\":\"Access denied\"}".utf8))
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        do {
            try await backend.update("rooms", id: UUID(), value: ["name": "New"])
            XCTFail("Expected no update")
        } catch { XCTAssertTrue(error.localizedDescription.contains("No record")) }
        do {
            let _: [Room] = try await backend.list("rooms")
            XCTFail("Expected denial")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Access denied")) }
    }
    func testCorruptRoomResponseFailsWithoutReplacingOldData() async throws {
        let auth = try authData()
        let backend = backend { request in
            request.url!.path.contains("/auth/") ? (200, auth) : (200, Data("[{\"id\":\"broken\"}]".utf8))
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        let store = Store(backend: backend)
        let room = Room(project_id: UUID(), house_id: UUID(), name: "Original")
        store.rooms = [room]
        do {
            try await store.loadRooms(House(id: room.house_id, project_id: room.project_id, name: "House"))
            XCTFail("Expected decoding error")
        } catch { XCTAssertTrue(error is DecodingError) }
        XCTAssertEqual(store.rooms, [room])
    }
    /// `scope_level` has no default arguments in the design, so `h` and `r` are sent as explicit nulls.
    func testScopeLevelSendsEveryArgumentAndReadsTheLevel() async throws {
        let auth = try authData()
        let project = Project(name: "Site")
        var body: [String: Any]?
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            XCTAssertEqual(request.url!.path, "/rest/v1/rpc/scope_level")
            body = try JSONSerialization.jsonObject(with: request.bodyStreamData()) as? [String: Any]
            return (200, Data("3".utf8))
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        let level = try await Store(backend: backend).level(on: .project(project))
        XCTAssertEqual(level, .responsible)
        let sent = try XCTUnwrap(body)
        XCTAssertEqual(sent["p"] as? String, project.id.uuidString)
        XCTAssertTrue(sent["h"] is NSNull)
        XCTAssertTrue(sent["r"] is NSNull)
    }
    /// A new room carries only columns of the design that clients may set, and lands in its house.
    func testCreatingRoomSendsOnlyDesignColumns() async throws {
        let auth = try authData()
        let house = House(project_id: UUID(), name: "House A")
        var sentRoom: [String: Any]?
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            if request.url!.path == "/rest/v1/rooms", request.httpMethod == "POST" {
                sentRoom = try JSONSerialization.jsonObject(with: request.bodyStreamData()) as? [String: Any]
                return (201, Data())
            }
            return (200, Data("[]".utf8))
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        try await Store(backend: backend).createRoom(in: house, name: "Kitchen")
        let room = try XCTUnwrap(sentRoom)
        XCTAssertEqual(
            Set(room.keys), ["id", "house_id", "project_id", "name", "height", "length", "width", "status"])
        XCTAssertEqual(room["house_id"] as? String, house.id.uuidString)
        XCTAssertEqual(room["project_id"] as? String, house.project_id.uuidString)
        XCTAssertEqual(room["status"] as? String, "planned")
    }
    /// Grants on a project are the rows without house and room; names come from the user's profile.
    func testProjectGrantsAskForTheProjectScopeOnly() async throws {
        let auth = try authData()
        let project = Project(name: "Site")
        let person = UUID()
        var query: String?
        let backend = backend { request in
            if request.url!.path.contains("/auth/") { return (200, auth) }
            query = request.url!.query
            return (
                200,
                Data(
                    """
                    [{"id":"\(UUID())","user_id":"\(person)","role":"external","project_id":"\(project.id)",
                      "house_id":null,"room_id":null,"user":{"display_name":"Anna"}}]
                    """.utf8)
            )
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        let grants = try await Store(backend: backend).grants(on: .project(project))
        XCTAssertEqual(grants.map(\.role), [.external])
        XCTAssertEqual(grants.first?.user?.display_name, "Anna")
        let text = try XCTUnwrap(query?.removingPercentEncoding)
        XCTAssertTrue(text.contains("house_id=is.null"))
        XCTAssertTrue(text.contains("room_id=is.null"))
        XCTAssertTrue(text.contains("profiles!access_grants_user_id_fkey(display_name)"))
    }

}

extension URLRequest {
    /// URLProtocol hands over the body as a stream, not `httpBody`.
    func bodyStreamData() -> Data {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
