import Foundation

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
        let url = AppConfig.edgeFunctionURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        // Auth header
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            // Fall back to anon key for unauthenticated endpoints
            request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

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
        case 429:
            throw APIError.rateLimited
        case 404:
            throw APIError.notFound
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError("HTTP \(http.statusCode): \(msg)")
        }
    }

    // Convenience overload for empty body
    func post<Response: Decodable>(
        endpoint: String,
        responseType: Response.Type
    ) async throws -> Response {
        try await post(endpoint: endpoint, body: EmptyBody(), responseType: responseType)
    }
}

// MARK: - Response Wrapper

private struct SupabaseResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let error: SupabaseErrorBody?
}

private struct SupabaseErrorBody: Decodable {
    let code: String?
    let message: String?
}

private struct EmptyBody: Encodable {}

// MARK: - API Error

enum APIError: LocalizedError {
    case networkError(String)
    case serverError(String)
    case decodingError(String)
    case unauthorized
    case rateLimited
    case notFound

    var errorDescription: String? {
        switch self {
        case .networkError(let m):  return "Network error: \(m)"
        case .serverError(let m):   return m
        case .decodingError(let m): return "Data error: \(m)"
        case .unauthorized:         return "Session expired. Please sign in again."
        case .rateLimited:          return "Daily limit reached. Upgrade to Pro for unlimited access."
        case .notFound:             return "Content not found."
        }
    }
}
