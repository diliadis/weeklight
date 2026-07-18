import AppKit
import Foundation
import UserNotifications

@MainActor
final class SystemTimerNotificationScheduler: NSObject, TimerNotificationScheduling {
    private enum Identifier {
        static let finishingSoon = "weeklight.timer.finishing-soon"
        static let completion = "weeklight.timer.completion"
        static let allocationExceeded = "weeklight.timer.allocation-exceeded"

        static let all = [finishingSoon, completion, allocationExceeded]
    }

    private let center: UNUserNotificationCenter

    override init() {
        center = .current()
        super.init()
        center.delegate = self
    }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func replaceScheduledNotifications(
        with schedule: TimerNotificationSchedule,
        projectName: String
    ) {
        cancelScheduledTimerNotifications()

        if let delay = schedule.finishingSoonDelay {
            addNotification(
                identifier: Identifier.finishingSoon,
                title: "Finishing soon",
                body: "Your \(projectName) countdown is nearing completion.",
                delay: delay
            )
        }
        if let delay = schedule.completionDelay {
            addNotification(
                identifier: Identifier.completion,
                title: "Countdown complete",
                body: "Your \(projectName) focus session has finished.",
                delay: delay
            )
        }
        if let delay = schedule.allocationExceededDelay {
            addNotification(
                identifier: Identifier.allocationExceeded,
                title: "Weekly allocation reached",
                body: "You’ve used the planned time for \(projectName). The timer is still running.",
                delay: delay
            )
        }
    }

    func cancelScheduledTimerNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: Identifier.all)
    }

    private func addNotification(
        identifier: String,
        title: String,
        body: String,
        delay: TimeInterval
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, delay),
            repeats: false
        )
        center.add(
            UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
        )
    }
}

extension SystemTimerNotificationScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            let dashboard = NSApp.windows.first { $0.title == "Weeklight" }
                ?? NSApp.windows.first { $0.canBecomeKey }
            dashboard?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
