import Foundation
import OSLog

// MARK: - Analytics Event

enum AnalyticsEvent {
    case userSignedIn
    case userSignedUp
    case userSignedOut
    case onboardingCompleted(examType: String, state: String, studyGoal: String)
    case lessonStarted(lessonId: String, moduleTitle: String)
    case lessonCompleted(lessonId: String, moduleTitle: String, durationMinutes: Int)
    case quizStarted(quizType: String)
    case quizCompleted(quizType: String, score: Double, passed: Bool)
    case weakTopicReviewStarted
    case tutorMessageSent(contextType: String)
    case tutorQuotaReached
    case necSearched(query: String)
    case necExplained(code: String)
    case necExplanationQuotaReached
    case paywallShown(context: String)
    case purchaseStarted(productId: String)
    case purchaseCompleted(productId: String)
    case purchaseRestored
    case notificationPermissionGranted
    case notificationPermissionDenied
    case supportOpened(channel: String)
    case contentIssueReported(context: String)
    case accountDeletionRequested
    case runtimeError(surface: String, message: String)

    nonisolated var name: String {
        switch self {
        case .userSignedIn: return "user_signed_in"
        case .userSignedUp: return "user_signed_up"
        case .userSignedOut: return "user_signed_out"
        case .onboardingCompleted: return "onboarding_completed"
        case .lessonStarted: return "lesson_started"
        case .lessonCompleted: return "lesson_completed"
        case .quizStarted: return "quiz_started"
        case .quizCompleted: return "quiz_completed"
        case .weakTopicReviewStarted: return "weak_topic_review_started"
        case .tutorMessageSent: return "tutor_message_sent"
        case .tutorQuotaReached: return "tutor_quota_reached"
        case .necSearched: return "nec_searched"
        case .necExplained: return "nec_explained"
        case .necExplanationQuotaReached: return "nec_explanation_quota_reached"
        case .paywallShown: return "paywall_shown"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseRestored: return "purchase_restored"
        case .notificationPermissionGranted: return "notification_permission_granted"
        case .notificationPermissionDenied: return "notification_permission_denied"
        case .supportOpened: return "support_opened"
        case .contentIssueReported: return "content_issue_reported"
        case .accountDeletionRequested: return "account_deletion_requested"
        case .runtimeError: return "runtime_error"
        }
    }

    nonisolated var properties: [String: Any] {
        switch self {
        case .onboardingCompleted(let examType, let state, let studyGoal):
            return ["exam_type": examType, "state": state, "study_goal": studyGoal]
        case .lessonStarted(let lessonId, let moduleTitle):
            return ["lesson_id": lessonId, "module_title": moduleTitle]
        case .lessonCompleted(let lessonId, let moduleTitle, let durationMinutes):
            return ["lesson_id": lessonId, "module_title": moduleTitle, "duration_minutes": durationMinutes]
        case .quizStarted(let quizType):
            return ["quiz_type": quizType]
        case .quizCompleted(let quizType, let score, let passed):
            return ["quiz_type": quizType, "score": score, "passed": passed]
        case .tutorMessageSent(let contextType):
            return ["context_type": contextType]
        case .necSearched(let query):
            return ["query": query]
        case .necExplained(let code):
            return ["nec_code": code]
        case .paywallShown(let context):
            return ["context": context]
        case .purchaseStarted(let productId), .purchaseCompleted(let productId):
            return ["product_id": productId]
        case .supportOpened(let channel):
            return ["channel": channel]
        case .contentIssueReported(let context):
            return ["context": context]
        case .runtimeError(let surface, let message):
            return ["surface": surface, "message": message]
        default:
            return [:]
        }
    }
}

// MARK: - Protocol

protocol AnalyticsServiceProtocol: AnyObject, Sendable {
    nonisolated func track(_ event: AnalyticsEvent)
    nonisolated func identify(userId: String, examType: String, state: String)
}

// MARK: - Debug Logger

final class MockAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tehso.wattwise", category: "analytics")

    nonisolated func track(_ event: AnalyticsEvent) {
        let propsString = event.properties.isEmpty ? "" : " \(String(describing: event.properties))"
        logger.debug("[Analytics] \(event.name, privacy: .public)\(propsString, privacy: .public)")
    }

    nonisolated func identify(userId: String, examType: String, state: String) {
        logger.debug("[Analytics] identify userId=\(userId, privacy: .public) examType=\(examType, privacy: .public) state=\(state, privacy: .public)")
    }
}

// MARK: - Supabase-backed Analytics

final class SupabaseAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    private struct QueuedEvent: Codable {
        let name: String
        let properties: [String: String]
        let occurredAt: String
        let userId: String?
        let examType: String?
        let state: String?
    }

    private let logger = Logger(subsystem: "com.tehso.wattwise", category: "analytics")
    private let session: URLSession
    private let queueKey = "ww_analytics_event_queue_v1"
    private let identityKey = "ww_analytics_identity_v1"
    private let deviceIDKey = "ww_analytics_device_id_v1"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }

    nonisolated func track(_ event: AnalyticsEvent) {
        let payload = makeQueuedEvent(name: event.name, properties: stringify(event.properties))
        logger.debug("[Analytics] \(payload.name, privacy: .public) \(String(describing: payload.properties), privacy: .public)")
        Task {
            await flushQueueIfNeeded()
            await sendOrQueue(payload)
        }
    }

    nonisolated func identify(userId: String, examType: String, state: String) {
        let identity = ["user_id": userId, "exam_type": examType, "state": state]
        UserDefaults.standard.set(identity, forKey: identityKey)
        let payload = makeQueuedEvent(name: "identify", properties: identity)
        Task { await sendOrQueue(payload) }
    }

    nonisolated private func flushQueueIfNeeded() async {
        let queued = loadQueue()
        guard queued.isEmpty == false else { return }

        var remaining: [QueuedEvent] = []
        for event in queued {
            let sent = await send(event)
            if !sent {
                remaining.append(event)
            }
        }
        saveQueue(remaining)
    }

    nonisolated private func sendOrQueue(_ event: QueuedEvent) async {
        let sent = await send(event)
        guard !sent else { return }

        var queue = loadQueue()
        queue.append(event)
        saveQueue(Array(queue.suffix(50)))
    }

    nonisolated private func send(_ event: QueuedEvent) async -> Bool {
        guard let url = URL(string: "\(AppConfig.edgeFunctionURL.absoluteString)/track_client_event") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        if let token = UserDefaults.standard.string(forKey: "ww_access_token"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "event_name": event.name,
            "properties": event.properties,
            "occurred_at": event.occurredAt,
            "user_id": event.userId as Any,
            "exam_type": event.examType as Any,
            "state": event.state as Any,
            "device_id": deviceID(),
            "platform": "ios"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            logger.error("Analytics send failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    nonisolated private func makeQueuedEvent(name: String, properties: [String: String]) -> QueuedEvent {
        let identity = UserDefaults.standard.dictionary(forKey: identityKey)
        return QueuedEvent(
            name: name,
            properties: properties,
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            userId: identity?["user_id"] as? String,
            examType: identity?["exam_type"] as? String,
            state: identity?["state"] as? String
        )
    }

    nonisolated private func stringify(_ properties: [String: Any]) -> [String: String] {
        properties.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[entry.key] = String(describing: entry.value)
        }
    }

    nonisolated private func deviceID() -> String {
        if let stored = UserDefaults.standard.string(forKey: deviceIDKey), !stored.isEmpty {
            return stored
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: deviceIDKey)
        return value
    }

    nonisolated private func loadQueue() -> [QueuedEvent] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let queue = try? JSONDecoder().decode([QueuedEvent].self, from: data) else {
            return []
        }
        return queue
    }

    nonisolated private func saveQueue(_ queue: [QueuedEvent]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }
}

// MARK: - Shared accessor

enum Analytics {
    nonisolated static let shared: any AnalyticsServiceProtocol = {
        let processInfo = ProcessInfo.processInfo
        let isPreview = processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isTest = processInfo.environment["XCTestConfigurationFilePath"] != nil || processInfo.arguments.contains("UITEST_MODE")
        return isPreview || isTest ? MockAnalyticsService() : SupabaseAnalyticsService()
    }()

    nonisolated static func track(_ event: AnalyticsEvent) {
        shared.track(event)
    }

    nonisolated static func trackError(surface: String, message: String) {
        shared.track(.runtimeError(surface: surface, message: message))
    }
}
