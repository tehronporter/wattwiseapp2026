import Foundation
import UserNotifications

// MARK: - Study Notification Scheduler
//
// Schedules two types of local notifications:
//   1. Daily study reminder — fires at the user's preferred time (default 7 PM)
//   2. Streak protection — fires at 8 PM if the user hasn't studied today
//
// All notifications are local (no APNs account needed).
// Call `requestPermissionAndSchedule()` after the user is authenticated.

@MainActor
final class StudyNotificationScheduler {
    static let shared = StudyNotificationScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission + Schedule

    func requestPermissionAndSchedule(user: WWUser) async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { scheduleAll(for: user) }
        case .authorized, .provisional:
            scheduleAll(for: user)
        default:
            break
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func scheduleAll(for user: WWUser) {
        center.removeAllPendingNotificationRequests()
        scheduleDailyReminder(for: user)
        scheduleStreakProtection(for: user)
        if let days = user.daysUntilExam {
            scheduleExamApproachingAlert(daysRemaining: days, examType: user.examType)
        }
    }

    // Fires every day at 7 PM
    private func scheduleDailyReminder(for user: WWUser) {
        let content = UNMutableNotificationContent()
        content.title = "Time to study"
        content.body = dailyBody(for: user)
        content.sound = .default

        var components = DateComponents()
        components.hour = 19
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "ww.daily_reminder", content: content, trigger: trigger)
        center.add(request)
    }

    // Fires at 8 PM — only meaningful if the user hasn't studied.
    // We can't detect study activity from the notification layer, so we always
    // schedule it and rely on the app foregrounding to cancel it if the user studied.
    private func scheduleStreakProtection(for user: WWUser) {
        let content = UNMutableNotificationContent()
        content.title = streakProtectionTitle(streakDays: user.streakDays)
        content.body = "Open WattWise and log at least a few minutes to keep it going."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "ww.streak_protection", content: content, trigger: trigger)
        center.add(request)
    }

    // One-time alert when exam is 7 days away and again at 1 day
    private func scheduleExamApproachingAlert(daysRemaining: Int, examType: ExamType) {
        let milestones: [Int] = [30, 14, 7, 3, 1]
        for milestone in milestones where daysRemaining >= milestone {
            guard let fireDate = Calendar.current.date(
                byAdding: .day,
                value: daysRemaining - milestone,
                to: Calendar.current.startOfDay(for: Date())
            ) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(milestone) day\(milestone == 1 ? "" : "s") until your \(examType.displayName) exam"
            content.body = milestone <= 3
                ? "Final stretch — focus on weak areas and trust your prep."
                : "Keep the momentum going. Consistent daily study beats last-minute cramming."
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "ww.exam_approaching.\(milestone)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Cancel streak alert when user studies (call from save_progress)

    func cancelStreakProtectionForToday() {
        // Reschedule streak protection to tomorrow by cancelling today's pending one.
        // The daily repeating trigger will re-fire tomorrow automatically.
        center.removePendingNotificationRequests(withIdentifiers: ["ww.streak_protection"])
        // Reschedule with repeating so it comes back tomorrow.
        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak"
        content.body = "Open WattWise and log at least a few minutes to keep it going."
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "ww.streak_protection", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Copy helpers

    private func dailyBody(for user: WWUser) -> String {
        let goal = user.studyGoal
        switch goal {
        case .casual:   return "Even 15 minutes today keeps your streak alive."
        case .moderate: return "30 minutes of focused study moves you closer to passing."
        case .intensive: return "Ready for a 60-minute session? Your exam is waiting."
        }
    }

    private func streakProtectionTitle(streakDays: Int) -> String {
        if streakDays == 0 { return "Start your streak today" }
        if streakDays == 1 { return "Protect your 1-day streak" }
        return "Don't break your \(streakDays)-day streak"
    }
}
