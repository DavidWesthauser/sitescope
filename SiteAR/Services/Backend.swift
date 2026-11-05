import Foundation
import Security

struct User: Codable, Sendable { var id: UUID; var email: String? }
struct AuthSession: Codable, Sendable {
    var access_token: String; var refresh_token: String; var expires_at: Double?; var user: User
}
enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): text } }
}
struct Configuration {
    let url: URL; let key: String
    static func load() throws -> Configuration {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty, !key.contains("YOUR_") else { throw AppError.message("Configure SUPABASE_URL and SUPABASE_ANON_KEY in Config.xcconfig. See README.") }
        return Configuration(url: url, key: key)
    }
}

/// No service-role key. Every request is subject to Supabase RLS.
@MainActor final class Backend {
    private let config: Configuration
    private let urlSession: URLSession
    private let persistSession: Bool
    private(set) var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    init(config: Configuration, urlSession: URLSession = .shared, persistSession: Bool = true) {
        self.config = config; self.urlSession = urlSession; self.persistSession = persistSession
        if persistSession { session = try? JSONDecoder().decode(AuthSession.self, from: Vault.read()) }
    }
    var user: User? { session?.user }
    private func raw(_ path: String, method: String = "GET", body: Data? = nil, token: String? = nil, contentType: String = "application/json", prefer: String? = nil) async throws -> Data {
        guard let url = URL(string: path, relativeTo: config.url) else { throw AppError.message("Invalid server URL") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(prefer, forHTTPHeaderField: "Prefer")
        request.timeoutInterval = 60
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = object?["msg"] as? String ?? object?["message"] as? String ?? object?["error_description"] as? String ?? "Request failed"
            throw AppError.message("\(message) (\(code)). Refresh or sign in again if access expired.")
        }
        return data
    }
    func authenticate(email: String, password: String, register: Bool) async throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await raw(register ? "/auth/v1/signup" : "/auth/v1/token?grant_type=password", method: "POST", body: body)
        if let result = try? JSONDecoder().decode(AuthSession.self, from: data) { try save(result); return true }
        if register { return false }
        throw AppError.message("The server returned an invalid authentication session.")
    }
    private func save(_ value: AuthSession) throws { if persistSession { try Vault.write(JSONEncoder().encode(value)) }; session = value }
    private func token() async throws -> String {
        guard let session else { throw AppError.message("Please sign in.") }
        if let expiry = session.expires_at, expiry > Date().timeIntervalSince1970 + 90 { return session.access_token }
        if let task = refreshTask { return try await task.value.access_token }
        let task = Task<AuthSession, Error> {
            let data = try await raw("/auth/v1/token?grant_type=refresh_token", method: "POST", body: JSONSerialization.data(withJSONObject: ["refresh_token": session.refresh_token]))
            let value = try JSONDecoder().decode(AuthSession.self, from: data); try save(value); return value
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value.access_token
    }
    func signOut() async {
        if let access = try? await token() { _ = try? await raw("/auth/v1/logout", method: "POST", token: access) }
        if persistSession { Vault.delete() }; session = nil
    }
    func list<T: Decodable>(_ table: String, query: String = "") async throws -> [T] {
        let access = try await token()
        return try JSONDecoder().decode([T].self, from: await raw("/rest/v1/\(table)?select=*\(query)", token: access))
    }
    func insert<T: Encodable>(_ table: String, value: T) async throws {
        let access = try await token()
        _ = try await raw("/rest/v1/\(table)", method: "POST", body: JSONEncoder().encode(value), token: access, prefer: "return=minimal")
    }
    func update<T: Encodable>(_ table: String, id: UUID, value: T) async throws {
        let access = try await token()
        let data = try await raw("/rest/v1/\(table)?id=eq.\(id)", method: "PATCH", body: JSONEncoder().encode(value), token: access, prefer: "return=representation")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else { throw AppError.message("No record was updated. Your access may have changed; refresh.") }
    }
    func delete(_ table: String, id: UUID) async throws {
        let access = try await token()
        let data = try await raw("/rest/v1/\(table)?id=eq.\(id)", method: "DELETE", token: access, prefer: "return=representation")
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty else { throw AppError.message("Nothing was deleted. Refresh your access.") }
    }
    func rpc(_ name: String, arguments: [String: String]) async throws {
        let access = try await token()
        _ = try await raw("/rest/v1/rpc/\(name)", method: "POST", body: JSONSerialization.data(withJSONObject: arguments), token: access)
    }
    func upload(path: String, data: Data, type: String) async throws {
        let access = try await token()
        _ = try await raw("/storage/v1/object/room-assets/\(path)", method: "POST", body: data, token: access, contentType: type)
    }
    func download(path: String) async throws -> Data {
        let access = try await token()
        let data = try await raw("/storage/v1/object/authenticated/room-assets/\(path)", token: access)
        guard data.count <= 100_000_000 else { throw AppError.message("Room file exceeds the 100 MB safety limit.") }
        return data
    }
}

enum Vault {
    private static var base: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "sitescope.auth", kSecAttrAccount as String: "session"] }
    static func read() throws -> Data {
        var query = base; query[kSecReturnData as String] = true
        var value: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &value)
        guard status == errSecSuccess, let data = value as? Data else { throw AppError.message("No saved login") }; return data
    }
    static func write(_ data: Data) throws {
        var attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound { attributes.merge(base) { a,_ in a }; status = SecItemAdd(attributes as CFDictionary, nil) }
        guard status == errSecSuccess else { throw AppError.message("Could not securely save your login (\(status)).") }
    }
    static func delete() { SecItemDelete(base as CFDictionary) }
}
