import CoreData
import Darwin
import Foundation

private struct VerificationFailure: Error {
    let count: Int
}

@MainActor
private final class RecordingTimerNotificationScheduler: TimerNotificationScheduling {
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

@MainActor
private final class RecordingLaunchAtLoginController: LaunchAtLoginControlling {
    var state: LaunchAtLoginState = .disabled
    var registerCount = 0
    var unregisterCount = 0
    var openSettingsCount = 0

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

@main
struct WeeklightVerification {
    @MainActor
    static func main() async throws {
        var failureCount = 0
        var checkCount = 0

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checkCount += 1
            if !condition() {
                failureCount += 1
                fputs("FAIL: \(message)\n", stderr)
            }
        }

        let utc = TimeZone(secondsFromGMT: 0)!
        let calendar = WeekMath.mondayFirstCalendar(timeZone: utc)
        let wednesday = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 15, hour: 13)
        )!
        let monday = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 13)
        )!
        check(
            WeekMath.startOfWeek(containing: wednesday, calendar: calendar) == monday,
            "Weeks must start on Monday"
        )

        let week = DateInterval(start: monday, duration: 7 * 24 * 60 * 60)
        check(
            TrackingMath.overlapDuration(
                startedAt: monday.addingTimeInterval(-30 * 60),
                endedAt: monday.addingTimeInterval(90 * 60),
                interval: week
            ) == 90 * 60,
            "Cross-boundary sessions must be clipped to the selected week"
        )
        check(
            !TrackingMath.intervalsOverlap(
                start: monday,
                end: monday.addingTimeInterval(60),
                otherStart: monday.addingTimeInterval(60),
                otherEnd: monday.addingTimeInterval(120)
            ),
            "Touching sessions must not count as overlapping"
        )
        check(
            TrackingMath.isCountdownFinishingSoon(
                totalDuration: 30 * 60,
                remainingDuration: 3 * 60
            ),
            "Countdowns must enter the finishing-soon state near zero"
        )
        check(
            !TrackingMath.isCountdownFinishingSoon(
                totalDuration: 30 * 60,
                remainingDuration: 4 * 60
            ),
            "Countdowns must not warn too early"
        )
        check(DurationText.compact(0) == "0m", "Zero duration formatting")
        check(DurationText.compact(45 * 60) == "45m", "Minute-only duration formatting")
        check(DurationText.compact(2 * 60 * 60) == "2h", "Hour-only duration formatting")
        check(DurationText.compact(7_500) == "2h 5m", "Mixed duration formatting")
        check(DurationText.clock(3_661) == "01:01:01", "Timer clock formatting")
        check(
            DurationText.countdownClock(59.1) == "00:01:00",
            "Countdown clocks must round up partial seconds"
        )
        check(
            FocusMetadata.uniqueCleanTags([
                " #Deep Work ",
                "deep   work",
                "GitHub"
            ]) == ["Deep Work", "GitHub"],
            "Tags must be cleaned and deduplicated case-insensitively"
        )
        let workLink = URL(
            string: "https://github.com/acme/weeklight/commit/abcdef123456"
        )!
        check(
            FocusMetadata.githubReference(for: workLink)?.compactTitle
                == "acme/weeklight · commit abcdef1",
            "GitHub commit links must receive compact work labels"
        )
        check(
            FocusMetadata.safeLinks(
                in: "https://example.com javascript:alert(1)"
            ).map(\.absoluteString) == ["https://example.com"],
            "Only HTTP and HTTPS links may be opened from focus notes"
        )

        let notificationPreferences = TimerNotificationPreferences(
            isEnabled: true,
            finishingSoonEnabled: true,
            completionEnabled: true,
            allocationExceededEnabled: true
        )
        let countdownNotifications = TimerNotificationPolicy.schedule(
            countdownDuration: 30 * 60,
            elapsedDuration: 10 * 60,
            allocationRemaining: 8 * 60 * 60,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: notificationPreferences
        )
        check(
            countdownNotifications.finishingSoonDelay == 17 * 60
                && countdownNotifications.completionDelay == 20 * 60,
            "Countdown alerts must use the finishing threshold and completion time"
        )
        check(
            countdownNotifications.allocationExceededDelay == nil,
            "Allocation alerts must not outlive a shorter countdown"
        )
        let allocationNotification = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 0,
            allocationRemaining: 45 * 60,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: notificationPreferences
        )
        check(
            allocationNotification.allocationExceededDelay == 45 * 60,
            "Stopwatches must notify when the weekly allocation is crossed"
        )
        let allocationBoundaryNotification = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 0,
            allocationRemaining: 0,
            secondsUntilWeekEnds: 24 * 60 * 60,
            preferences: notificationPreferences
        )
        check(
            allocationBoundaryNotification.allocationExceededDelay == 1,
            "Allocation alerts must fire when tracking continues at the limit"
        )
        let nextWeekAllocation = TimerNotificationPolicy.schedule(
            countdownDuration: nil,
            elapsedDuration: 0,
            allocationRemaining: 2 * 60 * 60,
            secondsUntilWeekEnds: 60 * 60,
            preferences: notificationPreferences
        )
        check(
            nextWeekAllocation.allocationExceededDelay == nil,
            "Allocation alerts must not escape the current week"
        )

        let container = try PersistenceFactory.makeContainer(inMemory: true)
        let suiteName = "WeeklightVerification.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let notificationScheduler = RecordingTimerNotificationScheduler()
        let launchAtLoginController = RecordingLaunchAtLoginController()
        let model = AppModel(
            container: container,
            now: wednesday,
            startTicker: false,
            defaults: defaults,
            notificationScheduler: notificationScheduler,
            launchAtLoginController: launchAtLoginController
        )
        await model.refreshNotificationAuthorization()
        model.setLaunchAtLogin(true)
        check(
            model.launchAtLoginEnabled
                && model.launchAtLoginState == .enabled
                && launchAtLoginController.registerCount == 1,
            "Launch at login must register the main application"
        )
        model.setLaunchAtLogin(false)
        check(
            !model.launchAtLoginEnabled
                && model.launchAtLoginState == .disabled
                && launchAtLoginController.unregisterCount == 1,
            "Disabling launch at login must unregister the main application"
        )
        launchAtLoginController.state = .requiresApproval
        model.refreshLaunchAtLoginState()
        model.setLaunchAtLogin(true)
        check(
            model.launchAtLoginEnabled
                && model.launchAtLoginState == .requiresApproval
                && launchAtLoginController.openSettingsCount == 1,
            "Approval-required login items must route to System Settings"
        )
        launchAtLoginController.state = .disabled
        model.refreshLaunchAtLoginState()
        check(
            model.createProject(
                name: "Website redesign",
                colorHex: "4F7FFF",
                defaultWeeklyMinutes: 12 * 60
            ),
            "A valid project must be created"
        )
        check(
            !model.createProject(
                name: "website REDESIGN",
                colorHex: "7165E8",
                defaultWeeklyMinutes: 8 * 60
            ),
            "Duplicate project names must be rejected case-insensitively"
        )

        let firstProject = model.projects.first!
        check(
            model.allocationMinutes(
                for: firstProject,
                weekStart: model.selectedWeekStart
            ) == 12 * 60,
            "Creating a project must snapshot its weekly allocation"
        )

        check(
            model.createProject(
                name: "Mobile app",
                colorHex: "26A69A",
                defaultWeeklyMinutes: 10 * 60
            ),
            "A second unique project must be created"
        )
        let secondProject = model.projects.first { $0.name == "Mobile app" }!
        let timerStart = wednesday.addingTimeInterval(-2 * 60 * 60)
        let switchTime = timerStart.addingTimeInterval(45 * 60)
        check(model.startTimer(for: firstProject, at: timerStart), "Timer must start")
        check(
            model.startTimer(
                for: secondProject,
                noteMarkdown: "Implemented **timer recovery**\n\n\(workLink.absoluteString)",
                tagNames: ["Deep Work", "GitHub"],
                at: switchTime
            ),
            "Timer must switch"
        )
        check(
            model.entries.filter(\.isRunning).count == 1,
            "Only one timer may remain active"
        )
        check(
            model.entries.first { $0.project?.id == firstProject.id }?.endedAt == switchTime,
            "Switching must close the previous timer at the same instant"
        )

        let resumedSessionID = model.activeFocusSession?.id
        model.pauseTimer(at: switchTime.addingTimeInterval(15 * 60))
        check(model.activeEntry == nil, "Pausing must close the active segment")
        check(model.pausedProject?.id == secondProject.id, "Paused project must persist")
        model.resumeTimer(at: switchTime.addingTimeInterval(20 * 60))
        check(model.activeEntry?.project?.id == secondProject.id, "Paused timer must resume")
        check(
            model.activeFocusSession?.id == resumedSessionID
                && model.activeFocusSession?.sortedEntries.count == 2,
            "Pause and resume must remain one logical focus session"
        )
        check(
            model.activeFocusSession?.sortedTags.map(\.name)
                == ["Deep Work", "GitHub"],
            "Focus notes and tags must survive pause and resume"
        )
        model.stopTimer(at: switchTime.addingTimeInterval(30 * 60))

        let manualStart = wednesday.addingTimeInterval(-6 * 60 * 60)
        check(
            model.addManualEntry(
                project: firstProject,
                start: manualStart,
                end: manualStart.addingTimeInterval(60 * 60),
                note: "Planning",
                tagNames: ["Planning"]
            ),
            "A valid manual entry must be accepted"
        )
        check(
            !model.addManualEntry(
                project: firstProject,
                start: manualStart.addingTimeInterval(30 * 60),
                end: manualStart.addingTimeInterval(90 * 60),
                note: "Overlapping"
            ),
            "Overlapping manual entries must be rejected"
        )

        let manualEntry = model.entries.first {
            $0.startedAt == manualStart && $0.project?.id == firstProject.id
        }!
        let totalBeforeSplit = model.totalProgress(
            for: model.selectedWeekStart
        ).trackedSeconds
        let splitDate = manualStart.addingTimeInterval(25 * 60)
        check(
            model.splitEntry(
                manualEntry,
                at: splitDate,
                secondProject: secondProject,
                secondNote: "Delivery"
            ),
            "Completed sessions must be splittable"
        )
        check(
            model.entries.filter {
                $0.startedAt >= manualStart
                    && ($0.endedAt ?? $0.startedAt) <= manualStart.addingTimeInterval(60 * 60)
            }.count == 2,
            "Splitting must create two adjacent sessions"
        )
        check(
            model.totalProgress(for: model.selectedWeekStart).trackedSeconds
                == totalBeforeSplit,
            "Splitting must preserve total tracked time"
        )
        let splitEntry = model.entries.first { $0.startedAt == splitDate }!
        check(
            splitEntry.project?.id == secondProject.id && splitEntry.note == "Delivery",
            "The later split segment must support project reassignment and notes"
        )
        check(
            splitEntry.focusSession?.id != manualEntry.focusSession?.id
                && splitEntry.focusSession?.sortedTags.map(\.name) == ["Planning"],
            "Splitting must create a new focus session with copied tags"
        )
        check(
            !model.splitEntry(
                splitEntry,
                at: splitEntry.startedAt,
                secondProject: firstProject,
                secondNote: "Invalid"
            ) && model.entries.filter { $0.startedAt == splitDate }.count == 1,
            "Invalid splits must leave history unchanged"
        )
        let correctedEnd = splitEntry.startedAt.addingTimeInterval(20 * 60)
        check(
            model.updateEntry(
                splitEntry,
                project: firstProject,
                start: splitEntry.startedAt,
                end: correctedEnd,
                note: "  Corrected  "
            ),
            "Completed sessions must support correction"
        )
        check(
            splitEntry.project?.id == firstProject.id
                && splitEntry.endedAt == correctedEnd
                && splitEntry.note == "Corrected",
            "Corrections must update project, duration, and trimmed notes"
        )
        let deletedEntryID = splitEntry.id
        model.deleteEntry(splitEntry)
        check(
            !model.entries.contains { $0.id == deletedEntryID },
            "Deleting a completed session must remove it from history"
        )

        let countdownStart = wednesday.addingTimeInterval(2 * 60 * 60)
        model.refreshTimer(at: countdownStart, playsCompletionSound: false)
        check(
            model.startTimer(
                for: firstProject,
                countdownSeconds: 30 * 60,
                at: countdownStart
            ),
            "A valid countdown must start"
        )
        check(
            notificationScheduler.lastProjectName == firstProject.name
                && notificationScheduler.lastSchedule?.finishingSoonDelay == 27 * 60
                && notificationScheduler.lastSchedule?.completionDelay == 30 * 60,
            "Starting a countdown must register both native alerts"
        )
        model.refreshTimer(
            at: countdownStart.addingTimeInterval(10 * 60),
            playsCompletionSound: false
        )
        check(
            model.activeRemainingDuration == 20 * 60,
            "Countdown must show the remaining duration"
        )
        model.pauseTimer(at: countdownStart.addingTimeInterval(10 * 60))
        check(
            model.pausedCountdownSeconds == 20 * 60,
            "Pausing must preserve countdown time"
        )
        check(
            notificationScheduler.cancelCount > 0
                && notificationScheduler.lastSchedule == nil,
            "Pausing must cancel pending timer alerts"
        )
        model.resumeTimer(at: countdownStart.addingTimeInterval(15 * 60))
        model.refreshTimer(
            at: countdownStart.addingTimeInterval(35 * 60),
            playsCompletionSound: false
        )
        check(model.activeEntry == nil, "Countdown must stop automatically at zero")
        check(
            model.recentlyCompletedProjectName == firstProject.name,
            "Countdown completion must identify the project"
        )
        check(
            model.timerActivityState == .completed,
            "Completed countdowns must expose the completed icon state"
        )
        model.dismissCountdownCompletion()
        check(
            model.timerActivityState == .stopped
                && model.lastTrackedProject?.id == firstProject.id,
            "Stopped timers must retain the last project preview"
        )

        let migrationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Weeklight-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: migrationURL.path + suffix)
                )
            }
        }
        let legacyContainer = try PersistenceFactory.makeLegacyV1Container(
            at: migrationURL
        )
        let legacyProject = NSEntityDescription.insertNewObject(
            forEntityName: "Project",
            into: legacyContainer.viewContext
        )
        legacyProject.setValue(UUID(), forKey: "id")
        legacyProject.setValue("Legacy project", forKey: "name")
        legacyProject.setValue("697386", forKey: "colorHex")
        legacyProject.setValue(6 * 60, forKey: "defaultWeeklyMinutes")
        legacyProject.setValue(false, forKey: "isArchived")
        legacyProject.setValue(Date.now, forKey: "createdAt")
        legacyProject.setValue(Date.now, forKey: "updatedAt")
        try legacyContainer.viewContext.save()
        for store in legacyContainer.persistentStoreCoordinator.persistentStores {
            try legacyContainer.persistentStoreCoordinator.remove(store)
        }

        let migratedContainer = try PersistenceFactory.makeContainer(
            storeURL: migrationURL
        )
        let migratedProjects = try migratedContainer.viewContext.fetch(
            NSFetchRequest<Project>(entityName: "Project")
        )
        check(
            migratedProjects.first?.name == "Legacy project",
            "V1 stores must migrate without losing projects"
        )

        let v2MigrationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Weeklight-V2-\(UUID().uuidString).sqlite")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: v2MigrationURL.path + suffix)
                )
            }
        }
        let v2Container = try PersistenceFactory.makeLegacyV2Container(
            at: v2MigrationURL
        )
        let v2Context = v2Container.viewContext
        let v2Project = NSEntityDescription.insertNewObject(
            forEntityName: "Project",
            into: v2Context
        )
        let v2CreatedAt = Date(timeIntervalSince1970: 4_000_000)
        v2Project.setValue(UUID(), forKey: "id")
        v2Project.setValue("V2 project", forKey: "name")
        v2Project.setValue("4F7FFF", forKey: "colorHex")
        v2Project.setValue(8 * 60, forKey: "defaultWeeklyMinutes")
        v2Project.setValue(false, forKey: "isArchived")
        v2Project.setValue(v2CreatedAt, forKey: "createdAt")
        v2Project.setValue(v2CreatedAt, forKey: "updatedAt")

        let v2Entry = NSEntityDescription.insertNewObject(
            forEntityName: "TimeEntry",
            into: v2Context
        )
        v2Entry.setValue(UUID(), forKey: "id")
        v2Entry.setValue(v2CreatedAt, forKey: "startedAt")
        v2Entry.setValue(
            v2CreatedAt.addingTimeInterval(45 * 60),
            forKey: "endedAt"
        )
        v2Entry.setValue(
            "Legacy note with https://github.com/acme/weeklight/issues/42",
            forKey: "note"
        )
        v2Entry.setValue(TimeEntrySource.manual.rawValue, forKey: "sourceRawValue")
        v2Entry.setValue(v2CreatedAt, forKey: "createdAt")
        v2Entry.setValue(v2CreatedAt, forKey: "updatedAt")
        v2Entry.setValue(v2Project, forKey: "project")
        try v2Context.save()
        for store in v2Container.persistentStoreCoordinator.persistentStores {
            try v2Container.persistentStoreCoordinator.remove(store)
        }

        let migratedV2Container = try PersistenceFactory.makeContainer(
            storeURL: v2MigrationURL
        )
        let migratedV2Entries = try migratedV2Container.viewContext.fetch(
            NSFetchRequest<TimeEntry>(entityName: "TimeEntry")
        )
        let migratedV2Entry = migratedV2Entries.first
        check(
            migratedV2Entry?.focusSession?.noteMarkdown
                == "Legacy note with https://github.com/acme/weeklight/issues/42",
            "V2 entry notes must be backfilled into logical focus sessions"
        )
        check(
            migratedV2Entry?.focusSession?.sortedEntries.first?.id
                == migratedV2Entry?.id,
            "Migrated V2 entries must remain attached to their new focus session"
        )

        guard failureCount == 0 else {
            throw VerificationFailure(count: failureCount)
        }
        print("Weeklight verification passed: \(checkCount) checks")
    }
}
