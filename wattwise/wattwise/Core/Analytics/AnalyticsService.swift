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

// MARK: - Apple Analytics Service
//
// Uses OSLog for structured logging — visible in Console.app and Xcode Organizer.
// Aggregate usage metrics come from App Store Connect analytics automatically.

final class AppleAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.tehso.wattwise", category: "analytics")

    nonisolated func track(_ event: AnalyticsEvent) {
        let props = event.properties
        let propsString = props.isEmpty ? "" : " \(props.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.info("[Event] \(event.name, privacy: .public)\(propsString, privacy: .public)")
    }

    nonisolated func identify(userId: String, examType: String, state: String) {
        logger.info("[Identify] userId=\(userId, privacy: .private(mask: .hash)) examType=\(examType, privacy: .public) state=\(state, privacy: .public)")
    }
}

// MARK: - Shared accessor

enum Analytics {
    nonisolated static let shared: any AnalyticsServiceProtocol = AppleAnalyticsService()

    nonisolated static func track(_ event: AnalyticsEvent) {
        shared.track(event)
    }

    nonisolated static func trackError(surface: String, message: String) {
        shared.track(.runtimeError(surface: surface, message: message))
    }
}
