import Foundation

enum AuthRedirectConfiguration {
    nonisolated static let callbackScheme = "wattwise"
    nonisolated static let callbackHost = "auth"
    nonisolated static let callbackPath = "/callback"

    nonisolated static var appCallbackURL: URL {
        var components = URLComponents()
        components.scheme = callbackScheme
        components.host = callbackHost
        components.path = callbackPath
        return components.url!
    }

    nonisolated static func confirmationBridgeURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["WATTWISE_AUTH_CONFIRMATION_URL"],
           let url = URL(string: override.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil {
            return url
        }

        return AppConfig.edgeFunctionURL.appendingPathComponent("auth_confirmation")
    }

    nonisolated static func isAuthCallbackURL(_ url: URL) -> Bool {
        if url.scheme == callbackScheme {
            return url.host == callbackHost && url.path == callbackPath
        }

        let bridgeURL = confirmationBridgeURL()
        return url.scheme == bridgeURL.scheme &&
            url.host == bridgeURL.host &&
            url.path == bridgeURL.path
    }
}

struct PendingEmailConfirmation: Codable, Equatable, Sendable {
    let email: String
    let examType: ExamType
    let state: String
    let studyGoal: StudyGoal
    let requestedAt: Date

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum AuthSignUpResult: Sendable {
    case authenticated(WWUser)
    case awaitingEmailConfirmation(PendingEmailConfirmation)
}

enum AuthFlowRoute: Sendable {
    case onboarding(WWUser)
    case authenticated(WWUser)

    init(user: WWUser) {
        self = user.isOnboardingComplete ? .authenticated(user) : .onboarding(user)
    }
}

struct AuthCallbackPayload: Equatable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let type: String?
    let errorCode: String?
    let errorDescription: String?

    nonisolated var hasSessionTokens: Bool {
        accessToken?.isEmpty == false && refreshToken?.isEmpty == false
    }

    nonisolated var surfacedErrorMessage: String? {
        if let errorDescription, errorDescription.isEmpty == false {
            return errorDescription
        }
        return errorCode
    }

    nonisolated static func from(url: URL) -> AuthCallbackPayload? {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let fragmentItems = url.fragment.map(Self.queryItems(from:)) ?? []

        let merged = (queryItems + fragmentItems).reduce(into: [String: String]()) { partialResult, item in
            partialResult[item.name] = item.value ?? ""
        }

        let hasKnownKey = merged.keys.contains { key in
            [
                "access_token",
                "refresh_token",
                "type",
                "error",
                "error_code",
                "error_description"
            ].contains(key)
        }

        guard hasKnownKey else { return nil }

        return AuthCallbackPayload(
            accessToken: merged["access_token"],
            refreshToken: merged["refresh_token"],
            tokenType: merged["token_type"],
            expiresIn: merged["expires_in"].flatMap(Int.init),
            type: merged["type"],
            errorCode: merged["error_code"] ?? merged["error"],
            errorDescription: merged["error_description"]?.replacingOccurrences(of: "+", with: " ")
        )
    }

    private nonisolated static func queryItems(from string: String) -> [URLQueryItem] {
        var components = URLComponents()
        components.query = string.hasPrefix("?") ? String(string.dropFirst()) : string
        return components.queryItems ?? []
    }
}

enum PendingEmailConfirmationStore {
    private static let storageKey = "ww_pending_email_confirmation"

    static func load(defaults: UserDefaults = .standard) -> PendingEmailConfirmation? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(PendingEmailConfirmation.self, from: data)
    }

    static func save(_ pending: PendingEmailConfirmation, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
