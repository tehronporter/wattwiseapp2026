import Foundation

// MARK: - Session Expired Notification
// Posted by APIClient when a 401 cannot be recovered via token refresh.
// AppRootView observes this and transitions the user back to the sign-in screen.
extension Notification.Name {
    static let wwSessionExpired = Notification.Name("WattWise.SessionExpired")
}

// MARK: - API Client (Supabase Edge Functions)
//
// All requests: POST /functions/v1/{endpoint}
// Auth: Bearer {supabase_access_token}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var accessToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // Called by AuthService after sign-in to set the token for subsequent requests
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    // MARK: - Core request method

    func post<Request: Encodable, Response: Decodable>(
        endpoint: String,
        body: Request,
        responseType: Response.Type
    ) async throws -> Response {
        let bodyData = try JSONEncoder().encode(body)
        let initialRequest = makeRequest(endpoint: endpoint, bodyData: bodyData)

        do {
            return try await execute(initialRequest, responseType: responseType)
        } catch APIError.unauthorized {
            // On 401, try to restore the session (even if we didn't have a token initially).
            // The endpoint requires a user access token, not the anon key.
            guard let refreshedSession = await SupabaseAuthClient.shared.restoreSession() else {
                accessToken = nil
                // Notify the app shell to force the user back to sign-in.
                NotificationCenter.default.post(name: .wwSessionExpired, object: nil)
                throw APIError.unauthorized
            }

            accessToken = refreshedSession.accessToken
            let retriedRequest = makeRequest(endpoint: endpoint, bodyData: bodyData)
            return try await execute(retriedRequest, responseType: responseType)
        }
    }

    // Convenience overload for empty body
    func post<Response: Decodable>(
        endpoint: String,
        responseType: Response.Type
    ) async throws -> Response {
        try await post(endpoint: endpoint, body: EmptyBody(), responseType: responseType)
    }

    private func makeRequest(endpoint: String, bodyData: Data) -> URLRequest {
        let url = AppConfig.edgeFunctionURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        request.httpBody = bodyData

        // Always use the access token if available. If not available, send an empty bearer token
        // which will trigger a 401. The post() method will then attempt to restore the session and retry.
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer ", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200...299:
            do {
                let wrapper = try JSONDecoder().decode(SupabaseResponse<Response>.self, from: data)
                if let value = wrapper.data {
                    return value
                }
                throw APIError.serverError(wrapper.error?.message ?? "Empty response")
            } catch let decodeError as DecodingError {
                throw APIError.decodingError(decodeError.localizedDescription)
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            let wrapper = try? JSONDecoder().decode(SupabaseResponse<EmptyDecodable>.self, from: data)
            throw APIError.forbidden(wrapper?.error?.message ?? "Access unavailable.")
        case 429:
            throw APIError.rateLimited
        case 404:
            throw APIError.notFound
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError("HTTP \(http.statusCode): \(msg)")
        }
    }
}

// MARK: - Response Wrapper

private nonisolated struct SupabaseResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: SupabaseErrorBody?
}

private nonisolated struct SupabaseErrorBody: Decodable {
    let code: String?
    let message: String?
}

private nonisolated struct EmptyBody: Encodable {}
private nonisolated struct EmptyDecodable: Decodable {}

// MARK: - API Error

enum APIError: LocalizedError {
    case networkError(String)
    case serverError(String)
    case decodingError(String)
    case unauthorized
    case forbidden(String)
    case rateLimited
    case notFound

    var errorDescription: String? {
        switch self {
        case .networkError(let m):  return "Network error: \(m)"
        case .serverError(let m):   return m
        case .decodingError(let m): return "Data error: \(m)"
        case .unauthorized:         return "Session expired. Please sign in again."
        case .forbidden(let m):     return m
        case .rateLimited:          return "You've reached the limit for preview access. Choose Fast Track or Full Prep to keep going."
        case .notFound:             return "Content not found."
        }
    }
}
