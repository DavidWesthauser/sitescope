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
    /// Signs in through the stub and returns a remote store on the same backend.
    func signedIn(_ handler: @escaping (URLRequest) throws -> (Int, Data)) async throws -> RemoteStore {
        let auth = try authData()
        let backend = backend { request in
            request.url!.path.contains("/auth/") ? (200, auth) : try handler(request)
        }
        _ = try await backend.authenticate(email: "fixture@example.test", password: "password", register: false)
        return RemoteStore(backend: backend)
    }

    func testSignedInReadsSendKeyAndTokenAndReturnRows() async throws {
        let id = UUID()
        let remote = try await signedIn { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-access")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-fixture")
            return (200, Data(#"[{"id":"\#(id)","name":"Site","revision":4}]"#.utf8))
        }
        let rows = try await remote.fetchAll(.project)
        XCTAssertEqual(rows.first?["name"], .string("Site"))
        XCTAssertEqual(rows.first?["revision"]?.integer, 4)
    }
    func testUnconfirmedRegistrationDoesNotCreateLogin() async throws {
        let backend = backend { _ in (200, Data("{\"user\":{}}".utf8)) }
        let active = try await backend.authenticate(email: "new@example.test", password: "password", register: true)
        XCTAssertFalse(active)
        XCTAssertNil(backend.user)
    }
    /// Sync tells a conflict from a refusal by the status, and shows the server's own text.
    func testRefusalCarriesStatusAndReadableText() async throws {
        let remote = try await signedIn { _ in (403, Data(#"{"message":"Access denied"}"#.utf8)) }
        do {
            _ = try await remote.fetchAll(.room)
            XCTFail("Expected a refusal")
        } catch let failure as HTTPFailure {
            XCTAssertEqual(failure.status, 403)
            XCTAssertTrue(failure.message.hasPrefix("Access denied."))
        }
    }
    /// A write names the revision it is based on; an empty answer means someone else changed the row (T-029).
    func testConditionalUpdateNamesRevisionAndReportsConflict() async throws {
        let key = RecordKey(.room, UUID())
        var query: String?
        var body: [String: Any]?
        let remote = try await signedIn { request in
            query = request.url!.query
            body = try JSONSerialization.jsonObject(with: request.bodyStreamData()) as? [String: Any]
            return (200, Data("[]".utf8))
        }
        let row = try await remote.update(key, revision: 3, ["description": .string("New")])
        XCTAssertNil(row, "No row back means the revision no longer matched")
        XCTAssertTrue(query?.contains("revision=eq.3") == true)
        XCTAssertEqual(body?.keys.sorted(), ["description"])
    }
    /// `scope_level` has no default arguments in the design, so `h` and `r` are sent as explicit nulls.
    func testScopeLevelSendsEveryArgumentAndReadsTheLevel() async throws {
        let project = Project(name: "Site")
        var body: [String: Any]?
        let remote = try await signedIn { request in
            XCTAssertEqual(request.url!.path, "/rest/v1/rpc/scope_level")
            body = try JSONSerialization.jsonObject(with: request.bodyStreamData()) as? [String: Any]
            return (200, Data("3".utf8))
        }
        let level = try await remote.level(on: .project(project))
        XCTAssertEqual(level, .responsible)
        let sent = try XCTUnwrap(body)
        XCTAssertEqual(sent["p"] as? String, project.id.uuidString)
        XCTAssertTrue(sent["h"] is NSNull)
        XCTAssertTrue(sent["r"] is NSNull)
    }
    /// Grants on a project are the rows without house and room; names come from the user's profile.
    func testProjectGrantsAskForTheProjectScopeOnly() async throws {
        let project = Project(name: "Site")
        var query: String?
        let remote = try await signedIn { request in
            query = request.url!.query
            return (
                200,
                Data(
                    """
                    [{"id":"\(UUID())","user_id":"\(UUID())","role":"external","project_id":"\(project.id)",
                      "house_id":null,"room_id":null,"user":{"display_name":"Anna"}}]
                    """.utf8)
            )
        }
        let grants = try await remote.grants(on: .project(project))
        XCTAssertEqual(grants.map(\.role), [.external])
        XCTAssertEqual(grants.first?.user?.display_name, "Anna")
        let text = try XCTUnwrap(query?.removingPercentEncoding)
        XCTAssertTrue(text.contains("house_id=is.null"))
        XCTAssertTrue(text.contains("room_id=is.null"))
        XCTAssertTrue(text.contains("profiles!access_grants_user_id_fkey(display_name)"))
    }
    /// Files are never overwritten, so one that arrived before the app stopped counts as uploaded on retry.
    func testUploadOfAnExistingFileCountsAsDone() async throws {
        let remote = try await signedIn { _ in (409, Data(#"{"message":"The resource already exists"}"#.utf8)) }
        try await remote.upload(path: "p/r/map.worldmap", data: Data([1, 2, 3]), type: "application/octet-stream")
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
