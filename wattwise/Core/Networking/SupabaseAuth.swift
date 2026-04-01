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

    func signUp(email: String, password: String, redirectTo: URL?) async throws -> SignUpResponse {
        let body = SignUpRequest(
            email: email,
            password: password,
            redirectTo: redirectTo?.absoluteString
        )
        return try await post(path: "/signup", body: body, responseType: SignUpResponse.self)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> AuthSession {
        let body = ["email": email, "password": password]
        return try await post(path: "/token?grant_type=password", body: body, responseType: AuthSession.self)
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
        return try await post(path: "/token?grant_type=refresh_token", body: body, responseType: AuthSession.self)
    }

    func resendSignUpConfirmation(email: String) async throws {
        let body = ResendSignUpRequest(email: email)
        let _: EmptyResponse = try await post(path: "/resend", body: body, responseType: EmptyResponse.self)
    }

    // MARK: - Get User

    func getUser(accessToken: String) async throws -> SupabaseUser {
        var request = makeRequest(path: "/user", accessToken: accessToken)
        request.httpMethod = "GET"
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }

    func updateUserMetadata(accessToken: String, metadata: [String: String]) async throws -> SupabaseUser {
        var request = makeRequest(path: "/user", accessToken: accessToken)
        request.httpMethod = "PUT"
        request.httpBody = try JSONEncoder().encode(["data": metadata])

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
        return try decoder.decode(SupabaseUser.self, from: data)
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

    func session(fromAuthCallbackURL url: URL) async throws -> AuthSession {
        guard let payload = AuthCallbackPayload.from(url: url) else {
            throw AuthError.invalidCallback("That link could not be read. Request a new confirmation email and try again.")
        }

        if let message = payload.surfacedErrorMessage {
            throw AuthError.invalidCallback(message)
        }

        guard let accessToken = payload.accessToken,
              let refreshToken = payload.refreshToken else {
            throw AuthError.invalidCallback("That confirmation link is missing sign-in details. Request a new link and try again.")
        }

        let user = try await getUser(accessToken: accessToken)
        return AuthSession(
            accessToken: accessToken,
            tokenType: payload.tokenType ?? "bearer",
            expiresIn: payload.expiresIn,
            refreshToken: refreshToken,
            user: user
        )
    }

    // MARK: - Private helpers

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
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
        return try decoder.decode(Response.self, from: data)
    }

    private func makeRequest(path: String, accessToken: String?) -> URLRequest {
        // Use string concatenation to preserve query params (e.g. /token?grant_type=password).
        // appendingPathComponent() percent-encodes '?' which breaks Supabase auth endpoints.
        let url = URL(string: baseURL.absoluteString + path)!
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

// MARK: - Models

nonisolated struct AuthSession: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int?
    let refreshToken: String
    let user: SupabaseUser
}

nonisolated struct SignUpResponse: Decodable, Sendable {
    let user: SupabaseUser?
    let session: AuthSession?

    init(from decoder: Decoder) throws {
        if let session = try? AuthSession(from: decoder) {
            self.session = session
            self.user = session.user
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.user = try container.decodeIfPresent(SupabaseUser.self, forKey: .user)
        self.session = try container.decodeIfPresent(AuthSession.self, forKey: .session)
    }

    private enum CodingKeys: String, CodingKey {
        case user
        case session
    }
}

nonisolated struct SupabaseUser: Decodable, Sendable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?
    let appMetadata: AppMetadata?

    nonisolated struct UserMetadata: Decodable, Sendable {
        let displayName: String?
        let examType: String?
        let state: String?
        let studyGoal: String?
    }

    nonisolated struct AppMetadata: Decodable, Sendable {
        let provider: String?
    }
}

private nonisolated struct AuthErrorBody: Decodable, Sendable {
    let error: String?
    let error_description: String?
    let msg: String?
}

enum AuthError: LocalizedError {
    case server(String)
    case invalidCredentials
    case sessionExpired
    case invalidCallback(String)

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .invalidCredentials: return "Invalid email or password."
        case .sessionExpired: return "Session expired. Please sign in again."
        case .invalidCallback(let message): return message
        }
    }
}

private nonisolated struct SignUpRequest: Encodable, Sendable {
    let email: String
    let password: String
    let redirectTo: String?

    private enum CodingKeys: String, CodingKey {
        case email
        case password
        case redirectTo = "redirect_to"
    }
}

private nonisolated struct ResendSignUpRequest: Encodable, Sendable {
    let email: String
    let type = "signup"
}

private nonisolated struct EmptyResponse: Decodable, Sendable {}
