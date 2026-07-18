import Foundation

enum NotificationAuthorizationState: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
}

@MainActor
protocol TimerNotificationScheduling: AnyObject {
    func authorizationState() async -> NotificationAuthorizationState
    func requestAuthorization() async -> Bool
    func replaceScheduledNotifications(
        with schedule: TimerNotificationSchedule,
        projectName: String
    )
    func cancelScheduledTimerNotifications()
}
