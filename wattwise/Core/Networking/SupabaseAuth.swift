import Foundation

// MARK: - Supabase Auth REST Client
//
// Calls Supabase Auth endpoints directly via URLSession.
// No third-party SDK needed.

actor SupabaseAuthClient {
    static let shared = SupabaseAuthClient()

    private let session: URLSession
    private let baseURL: URL

    // Session storage keys
    private let tokenKey     = "ww_access_token"
    private let refreshKey   = "ww_refresh_token"
    private let userKey      = "ww_user_data"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.baseURL = URL(string: "\(AppConfig.supabaseURL)/auth/v1")!
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws -> AuthSession {
        let body = ["email": email, "password": password]
        return try await postAuth(path: "/signup", body: body)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> AuthSession {
        let body: [String: String] = ["email": email, "password": password]
        return try await postAuth(path: "/token?grant_type=password", body: body)
    }

    // MARK: - Sign Out

    func signOut(accessToken: String) async throws {
        var request = makeRequest(path: "/logout", accessToken: accessToken)
        request.httpMethod = "POST"
        _ = try await session.data(for: request)
    }

    // MARK: - Refresh Token

    func refreshSession(refreshToken: String) async throws -> AuthSession {
        let body = ["refresh_token": refreshToken]
        return try await postAuth(path: "/token?grant_type=refresh_token", body: body)
    }

    // MARK: - Get User

    func getUser(accessToken: String) async throws -> SupabaseUser {
        var request = makeRequest(path: "/user", accessToken: accessToken)
        request.httpMethod = "GET"
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    // MARK: - Session Persistence

    func saveSession(_ session: AuthSession) {
        UserDefaults.standard.set(session.accessToken, forKey: tokenKey)
        UserDefaults.standard.set(session.refreshToken, forKey: refreshKey)
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
        UserDefaults.standard.removeObject(forKey: userKey)
    }

    func restoreSession() async -> AuthSession? {
        guard UserDefaults.standard.string(forKey: tokenKey) != nil,
              let refresh = UserDefaults.standard.string(forKey: refreshKey) else { return nil }

        // Try to refresh the token
        do {
            let refreshed = try await refreshSession(refreshToken: refresh)
            saveSession(refreshed)
            return refreshed
        } catch {
            clearSession()
            return nil
        }
    }

    // MARK: - Private helpers

    private func postAuth(path: String, body: [String: String]) async throws -> AuthSession {
        var request = makeRequest(path: path, accessToken: nil)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse

        if let status = http?.statusCode, status >= 400 {
            if let errBody = try? JSONDecoder().decode(AuthErrorBody.self, from: data) {
                throw AuthError.server(errBody.msg ?? errBody.error_description ?? "Auth error")
            }
            throw AuthError.server("HTTP \(status)")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AuthSession.self, from: data)
    }

    private func makeRequest(path: String, accessToken: String?) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

// MARK: - Models

struct AuthSession: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String
    let user: SupabaseUser
}

struct SupabaseUser: Decodable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?
    let appMetadata: AppMetadata?

    struct UserMetadata: Decodable {
        let displayName: String?
        let examType: String?
        let state: String?
        let studyGoal: String?
    }

    struct AppMetadata: Decodable {
        let provider: String?
    }
}

private struct AuthErrorBody: Decodable {
    let error: String?
    let error_description: String?
    let msg: String?
}

enum AuthError: LocalizedError {
    case server(String)
    case invalidCredentials
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .invalidCredentials: return "Invalid email or password."
        case .sessionExpired: return "Session expired. Please sign in again."
        }
    }
}
