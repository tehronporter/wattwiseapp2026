import Foundation

// MARK: - Analytics Event

enum AnalyticsEvent {
    // Auth
    case userSignedIn
    case userSignedUp
    case userSignedOut

    // Onboarding
    case onboardingCompleted(examType: String, state: String, studyGoal: String)

    // Learn
    case lessonStarted(lessonId: String, moduleTitle: String)
    case lessonCompleted(lessonId: String, moduleTitle: String, durationMinutes: Int)

    // Practice
    case quizStarted(quizType: String)
    case quizCompleted(quizType: String, score: Double, passed: Bool)
    case weakTopicReviewStarted

    // Tutor
    case tutorMessageSent(contextType: String)
    case tutorQuotaReached

    // NEC
    case necSearched(query: String)
    case necExplained(code: String)
    case necExplanationQuotaReached

    // Paywall
    case paywallShown(context: String)
    case purchaseStarted(productId: String)
    case purchaseCompleted(productId: String)
    case purchaseRestored

    // Notifications
    case notificationPermissionGranted
    case notificationPermissionDenied

    var name: String {
        switch self {
        case .userSignedIn:                 return "user_signed_in"
        case .userSignedUp:                 return "user_signed_up"
        case .userSignedOut:                return "user_signed_out"
        case .onboardingCompleted:          return "onboarding_completed"
        case .lessonStarted:                return "lesson_started"
        case .lessonCompleted:              return "lesson_completed"
        case .quizStarted:                  return "quiz_started"
        case .quizCompleted:                return "quiz_completed"
        case .weakTopicReviewStarted:       return "weak_topic_review_started"
        case .tutorMessageSent:             return "tutor_message_sent"
        case .tutorQuotaReached:            return "tutor_quota_reached"
        case .necSearched:                  return "nec_searched"
        case .necExplained:                 return "nec_explained"
        case .necExplanationQuotaReached:   return "nec_explanation_quota_reached"
        case .paywallShown:                 return "paywall_shown"
        case .purchaseStarted:              return "purchase_started"
        case .purchaseCompleted:            return "purchase_completed"
        case .purchaseRestored:             return "purchase_restored"
        case .notificationPermissionGranted: return "notification_permission_granted"
        case .notificationPermissionDenied: return "notification_permission_denied"
        }
    }

    var properties: [String: Any] {
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
        case .purchaseStarted(let productId):
            return ["product_id": productId]
        case .purchaseCompleted(let productId):
            return ["product_id": productId]
        default:
            return [:]
        }
    }
}

// MARK: - Protocol

protocol AnalyticsServiceProtocol: AnyObject, Sendable {
    func track(_ event: AnalyticsEvent)
    func identify(userId: String, examType: String, state: String)
}

// MARK: - No-op (default until a real SDK is wired in)

final class MockAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let propsString = event.properties.isEmpty ? "" : " \(event.properties)"
        print("[Analytics] \(event.name)\(propsString)")
        #endif
    }

    func identify(userId: String, examType: String, state: String) {
        #if DEBUG
        print("[Analytics] identify userId=\(userId) examType=\(examType) state=\(state)")
        #endif
    }
}

// MARK: - Shared accessor (swap implementation here when adding Mixpanel/Amplitude/etc.)

enum Analytics {
    static let shared: any AnalyticsServiceProtocol = MockAnalyticsService()

    static func track(_ event: AnalyticsEvent) {
        shared.track(event)
    }
}
