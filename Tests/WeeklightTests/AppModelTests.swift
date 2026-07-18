import Foundation
import CoreData
import Testing
@testable import Weeklight

@MainActor
@Suite("Application model", .serialized)
struct AppModelTests {
    @Test("Creating a project also snapshots its current weekly allocation")
    func creatingProjectCreatesAllocation() throws {
        let fixture = try makeFixture()

        #expect(
            fixture.model.createProject(
                name: "Client work",
                colorHex: "4F7FFF",
                defaultWeeklyMinutes: 12 * 60
            )
        )
        let project = try #require(fixture.model.activeProjects.first)

        #expect(fixture.model.allocationMinutes(
            for: project,
            weekStart: fixture.model.selectedWeekStart
        ) == 12 * 60)
    }

    @Test("Switching projects closes the previous timer atomically")
    func switchingProjectsClosesPreviousTimer() throws {
        let fixture = try makeFixture()
        let first = try createProject(named: "First", in: fixture.model)
        let second = try createProject(named: "Second", in: fixture.model)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let switchTime = start.addingTimeInterval(45 * 60)

        #expect(fixture.model.startTimer(for: first, at: start))
        #expect(fixture.model.startTimer(for: second, at: switchTime))

        let firstEntry = try #require(
            fixture.model.entries.first { $0.project?.id == first.id }
        )
        #expect(firstEntry.endedAt == switchTime)
        #expect(fixture.model.activeEntry?.project?.id == second.id)
        #expect(fixture.model.entries.filter(\.isRunning).count == 1)
    }

    @Test("Pause and resume create distinct persisted segments")
    func pauseAndResume() throws {
        let fixture = try makeFixture()
        let project = try createProject(named: "Deep work", in: fixture.model)
        let start = Date(timeIntervalSince1970: 2_000_000)

        fixture.model.startTimer(
            for: project,
            noteMarkdown: "Implemented **timer recovery**",
            tagNames: ["Deep Work", "GitHub"],
            at: start
        )
        let focusSessionID = try #require(
            fixture.model.activeEntry?.focusSession?.id
        )
        fixture.model.pauseTimer(at: start.addingTimeInterval(20 * 60))

        #expect(fixture.model.activeEntry == nil)
        #expect(fixture.model.pausedProject?.id == project.id)

        fixture.model.resumeTimer(at: start.addingTimeInterval(30 * 60))

        #expect(fixture.model.activeEntry?.project?.id == project.id)
        #expect(fixture.model.entries.count == 2)
        #expect(fixture.model.activeEntry?.focusSession?.id == focusSessionID)
        #expect(fixture.model.focusSessions.count == 1)
        #expect(
            fixture.model.activeFocusSession?.sortedTags.map(\.name)
                == ["Deep Work", "GitHub"]
        )
    }

    @Test("Overlapping manual entries are rejected")
    func overlappingManualEntries() throws {
        let fixture = try makeFixture()
        let project = try createProject(named: "Research", in: fixture.model)
        let start = Date.now.addingTimeInterval(-4 * 60 * 60)

        #expect(
            fixture.model.addManualEntry(
                project: project,
                start: start,
                end: start.addingTimeInterval(60 * 60),
                note: "First"
            )
        )
        #expect(
            !fixture.model.addManualEntry(
                project: project,
                start: start.addingTimeInterval(30 * 60),
                end: start.addingTimeInterval(90 * 60),
                note: "Overlap"
            )
        )
        #expect(fixture.model.entries.count == 1)
    }

    @Test("Splitting a session preserves time and can reassign the later segment")
    func splittingSession() throws {
        let fixture = try makeFixture()
        let firstProject = try createProject(named: "Planning", in: fixture.model)
        let secondProject = try createProject(named: "Delivery", in: fixture.model)
        let start = Date.now.addingTimeInterval(-3 * 60 * 60)
        let end = start.addingTimeInterval(90 * 60)
        let splitDate = start.addingTimeInterval(35 * 60)

        #expect(
            fixture.model.addManualEntry(
                project: firstProject,
                start: start,
                end: end,
                note: "Initial work",
                tagNames: ["Planning"]
            )
        )
        let original = try #require(fixture.model.entries.first)

        #expect(
            fixture.model.splitEntry(
                original,
                at: splitDate,
                secondProject: secondProject,
                secondNote: "Implementation"
            )
        )
        #expect(fixture.model.entries.count == 2)
        #expect(
            fixture.model.entries.reduce(0) { $0 + $1.duration(at: end) }
                == end.timeIntervalSince(start)
        )

        let later = try #require(
            fixture.model.entries.first { $0.startedAt == splitDate }
        )
        #expect(later.project?.id == secondProject.id)
        #expect(later.note == "Implementation")
        #expect(later.endedAt == end)
        #expect(later.focusSession?.id != original.focusSession?.id)
        #expect(later.focusSession?.sortedTags.map(\.name) == ["Planning"])
    }

    @Test("A split at a session boundary is rejected without changing history")
    func invalidSplitIsRejected() throws {
        let fixture = try makeFixture()
        let project = try createProject(named: "Research", in: fixture.model)
        let start = Date.now.addingTimeInterval(-2 * 60 * 60)
        let end = start.addingTimeInterval(60 * 60)

        #expect(
            fixture.model.addManualEntry(
                project: project,
                start: start,
                end: end,
                note: "Read"
            )
        )
        let original = try #require(fixture.model.entries.first)

        #expect(
            !fixture.model.splitEntry(
                original,
                at: start,
                secondProject: project,
                secondNote: "Invalid"
            )
        )
        #expect(fixture.model.entries.count == 1)
        #expect(original.startedAt == start)
        #expect(original.endedAt == end)
    }

    @Test("Editing and deleting history immediately updates persisted entries")
    func editingAndDeletingHistory() throws {
        let fixture = try makeFixture()
        let originalProject = try createProject(named: "Original", in: fixture.model)
        let correctedProject = try createProject(named: "Corrected", in: fixture.model)
        let start = Date.now.addingTimeInterval(-2 * 60 * 60)
        let originalEnd = start.addingTimeInterval(60 * 60)
        let correctedEnd = start.addingTimeInterval(45 * 60)

        #expect(
            fixture.model.addManualEntry(
                project: originalProject,
                start: start,
                end: originalEnd,
                note: "Original note"
            )
        )
        let entry = try #require(fixture.model.entries.first)

        #expect(
            fixture.model.updateEntry(
                entry,
                project: correctedProject,
                start: start,
                end: correctedEnd,
                note: "  Corrected note  "
            )
        )
        #expect(entry.project?.id == correctedProject.id)
        #expect(entry.endedAt == correctedEnd)
        #expect(entry.note == "Corrected note")

        fixture.model.deleteEntry(entry)
        #expect(fixture.model.entries.isEmpty)
    }

    @Test("Countdowns preserve remaining time when paused and stop at zero")
    func countdownLifecycle() throws {
        let fixture = try makeFixture()
        let project = try createProject(named: "Focus", in: fixture.model)
        let start = Date(timeIntervalSince1970: 3_000_000)

        #expect(
            fixture.model.startTimer(
                for: project,
                countdownSeconds: 30 * 60,
                at: start
            )
        )
        fixture.model.refreshTimer(
            at: start.addingTimeInterval(10 * 60),
            playsCompletionSound: false
        )
        #expect(fixture.model.activeRemainingDuration == 20 * 60)

        fixture.model.pauseTimer(at: start.addingTimeInterval(10 * 60))
        #expect(fixture.model.pausedCountdownSeconds == 20 * 60)

        fixture.model.resumeTimer(at: start.addingTimeInterval(15 * 60))
        fixture.model.refreshTimer(
            at: start.addingTimeInterval(35 * 60),
            playsCompletionSound: false
        )

        #expect(fixture.model.activeEntry == nil)
        #expect(fixture.model.recentlyCompletedProjectName == project.name)
        #expect(
            fixture.model.entries
                .filter { $0.project?.id == project.id }
                .reduce(0) { $0 + $1.duration(at: start) } == 30 * 60
        )
    }

    @Test("Timer notifications are scheduled and cancelled with the timer lifecycle")
    func timerNotificationLifecycle() async throws {
        let fixture = try makeFixture()
        await fixture.model.refreshNotificationAuthorization()
        let project = try createProject(named: "Focused work", in: fixture.model)
        let start = Date(timeIntervalSince1970: 3_000_000)

        #expect(
            fixture.model.startTimer(
                for: project,
                countdownSeconds: 30 * 60,
                at: start
            )
        )
        #expect(fixture.notifications.lastProjectName == project.name)
        #expect(fixture.notifications.lastSchedule?.completionDelay == 30 * 60)
        #expect(fixture.notifications.lastSchedule?.finishingSoonDelay == 27 * 60)

        fixture.model.pauseTimer(at: start.addingTimeInterval(5 * 60))
        #expect(fixture.notifications.cancelCount > 0)
        #expect(fixture.notifications.lastSchedule == nil)
    }

    @Test("Launch at login registers and unregisters the main app")
    func launchAtLoginLifecycle() throws {
        let fixture = try makeFixture()

        fixture.model.setLaunchAtLogin(true)
        #expect(fixture.launchAtLogin.registerCount == 1)
        #expect(fixture.model.launchAtLoginState == .enabled)
        #expect(fixture.model.launchAtLoginEnabled)

        fixture.model.setLaunchAtLogin(false)
        #expect(fixture.launchAtLogin.unregisterCount == 1)
        #expect(fixture.model.launchAtLoginState == .disabled)
        #expect(!fixture.model.launchAtLoginEnabled)
    }

    @Test("An approval-required login item routes the user to System Settings")
    func launchAtLoginApproval() throws {
        let fixture = try makeFixture(
            launchAtLoginState: .requiresApproval
        )

        #expect(fixture.model.launchAtLoginEnabled)
        #expect(fixture.model.launchAtLoginState == .requiresApproval)

        fixture.model.setLaunchAtLogin(true)
        #expect(fixture.launchAtLogin.openSettingsCount == 1)
        #expect(fixture.launchAtLogin.registerCount == 0)
    }

    private func makeFixture(
        launchAtLoginState: LaunchAtLoginState = .disabled
    ) throws -> (
        model: AppModel,
        defaults: UserDefaults,
        notifications: TestTimerNotificationScheduler,
        launchAtLogin: TestLaunchAtLoginController
    ) {
        let container = try PersistenceFactory.makeContainer(inMemory: true)
        let suiteName = "WeeklightTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let notifications = TestTimerNotificationScheduler()
        let launchAtLogin = TestLaunchAtLoginController(
            state: launchAtLoginState
        )
        let model = AppModel(
            container: container,
            now: Date(timeIntervalSince1970: 3_000_000),
            startTicker: false,
            defaults: defaults,
            notificationScheduler: notifications,
            launchAtLoginController: launchAtLogin
        )
        return (model, defaults, notifications, launchAtLogin)
    }

    private func createProject(named name: String, in model: AppModel) throws -> Project {
        #expect(
            model.createProject(
                name: name,
                colorHex: "4F7FFF",
                defaultWeeklyMinutes: 8 * 60
            )
        )
        return try #require(model.projects.first { $0.name == name })
    }
}

@MainActor
private final class TestLaunchAtLoginController: LaunchAtLoginControlling {
    var state: LaunchAtLoginState
    var registerCount = 0
    var unregisterCount = 0
    var openSettingsCount = 0

    init(state: LaunchAtLoginState) {
        self.state = state
    }

    func register() throws {
        registerCount += 1
        state = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        state = .disabled
    }

    func openSystemSettings() {
        openSettingsCount += 1
    }
}

@MainActor
private final class TestTimerNotificationScheduler: TimerNotificationScheduling {
    var state: NotificationAuthorizationState = .authorized
    var lastSchedule: TimerNotificationSchedule?
    var lastProjectName: String?
    var cancelCount = 0

    func authorizationState() async -> NotificationAuthorizationState {
        state
    }

    func requestAuthorization() async -> Bool {
        state = .authorized
        return true
    }

    func replaceScheduledNotifications(
        with schedule: TimerNotificationSchedule,
        projectName: String
    ) {
        lastSchedule = schedule
        lastProjectName = projectName
    }

    func cancelScheduledTimerNotifications() {
        cancelCount += 1
        lastSchedule = nil
        lastProjectName = nil
    }
}
