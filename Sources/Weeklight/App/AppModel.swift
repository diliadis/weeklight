import AppKit
import Combine
import CoreData
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var allocations: [WeeklyAllocation] = []
    @Published private(set) var entries: [TimeEntry] = []
    @Published private(set) var focusSessions: [FocusSession] = []
    @Published private(set) var focusTags: [FocusTag] = []
    @Published private(set) var activeEntry: TimeEntry?
    @Published private(set) var pausedProjectID: UUID?
    @Published private(set) var pausedFocusSessionID: UUID?
    @Published private(set) var pausedCountdownSeconds: TimeInterval?
    @Published private(set) var recentlyCompletedProjectName: String?
    @Published private(set) var lastTrackedProjectID: UUID?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginState: LaunchAtLoginState = .disabled
    @Published private(set) var notificationsEnabled: Bool
    @Published private(set) var countdownFinishingNotificationEnabled: Bool
    @Published private(set) var countdownCompletionNotificationEnabled: Bool
    @Published private(set) var allocationNotificationEnabled: Bool
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown

    @Published var selectedWeekStart: Date
    @Published var now: Date
    @Published var weeklyCapacityMinutes: Int
    @Published var errorMessage: String?

    private let context: NSManagedObjectContext
    private let defaults: UserDefaults
    private let notificationScheduler: any TimerNotificationScheduling
    private let launchAtLoginController: any LaunchAtLoginControlling
    private var tickerTask: Task<Void, Never>?
    private var scheduledNotificationWeekStart: Date?

    private enum DefaultsKey {
        static let weeklyCapacityMinutes = "weeklyCapacityMinutes"
        static let pausedProjectID = "pausedProjectID"
        static let pausedFocusSessionID = "pausedFocusSessionID"
        static let pausedCountdownSeconds = "pausedCountdownSeconds"
        static let lastTrackedProjectID = "lastTrackedProjectID"
        static let notificationsEnabled = "notificationsEnabled"
        static let countdownFinishingNotificationEnabled = "countdownFinishingNotificationEnabled"
        static let countdownCompletionNotificationEnabled = "countdownCompletionNotificationEnabled"
        static let allocationNotificationEnabled = "allocationNotificationEnabled"
    }

    init(
        container: NSPersistentContainer,
        now: Date = .now,
        startTicker: Bool = true,
        defaults: UserDefaults = .standard,
        notificationScheduler: (any TimerNotificationScheduling)? = nil,
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        startupError: String? = nil
    ) {
        context = container.viewContext
        self.defaults = defaults
        self.notificationScheduler = notificationScheduler
            ?? SystemTimerNotificationScheduler()
        self.launchAtLoginController = launchAtLoginController
            ?? SystemLaunchAtLoginController()
        self.now = now
        selectedWeekStart = WeekMath.startOfWeek(containing: now)
        notificationsEnabled = defaults.object(
            forKey: DefaultsKey.notificationsEnabled
        ) as? Bool ?? true
        countdownFinishingNotificationEnabled = defaults.object(
            forKey: DefaultsKey.countdownFinishingNotificationEnabled
        ) as? Bool ?? true
        countdownCompletionNotificationEnabled = defaults.object(
            forKey: DefaultsKey.countdownCompletionNotificationEnabled
        ) as? Bool ?? true
        allocationNotificationEnabled = defaults.object(
            forKey: DefaultsKey.allocationNotificationEnabled
        ) as? Bool ?? true

        let storedCapacity = defaults.integer(forKey: DefaultsKey.weeklyCapacityMinutes)
        weeklyCapacityMinutes = storedCapacity > 0 ? storedCapacity : 40 * 60
        if storedCapacity == 0 {
            defaults.set(weeklyCapacityMinutes, forKey: DefaultsKey.weeklyCapacityMinutes)
        }

        if let storedID = defaults.string(forKey: DefaultsKey.pausedProjectID) {
            pausedProjectID = UUID(uuidString: storedID)
        }
        if let storedID = defaults.string(
            forKey: DefaultsKey.pausedFocusSessionID
        ) {
            pausedFocusSessionID = UUID(uuidString: storedID)
        }
        if let storedID = defaults.string(forKey: DefaultsKey.lastTrackedProjectID) {
            lastTrackedProjectID = UUID(uuidString: storedID)
        }
        let storedCountdown = defaults.double(forKey: DefaultsKey.pausedCountdownSeconds)
        if storedCountdown > 0 {
            pausedCountdownSeconds = storedCountdown
        }

        errorMessage = startupError
        launchAtLoginState = self.launchAtLoginController.state
        launchAtLoginEnabled = launchAtLoginState.isRegistered

        reload()
        recoverPausedFocusSessionIfNeeded()
        recoverActiveTimer(at: now)
        ensureAllocations(for: selectedWeekStart)

        if startTicker {
            beginTicker()
            if activeEntry != nil {
                prepareNotificationsIfNeeded()
            }
        }
    }

    var activeProjects: [Project] {
        projects.filter { !$0.isArchived }
    }

    var archivedProjects: [Project] {
        projects.filter(\.isArchived)
    }

    var pausedProject: Project? {
        guard let pausedProjectID else { return nil }
        return activeProjects.first { $0.id == pausedProjectID }
    }

    var activeFocusSession: FocusSession? {
        activeEntry?.focusSession
    }

    var pausedFocusSession: FocusSession? {
        guard let pausedFocusSessionID else { return nil }
        return focusSessions.first { $0.id == pausedFocusSessionID }
    }

    var suggestedTagNames: [String] {
        focusTags
            .sorted { $0.updatedAt > $1.updatedAt }
            .map(\.name)
    }

    var lastTrackedProject: Project? {
        guard let lastTrackedProjectID else { return nil }
        return projects.first { $0.id == lastTrackedProjectID }
    }

    var activeDuration: TimeInterval {
        activeEntry?.duration(at: now) ?? 0
    }

    var activeRemainingDuration: TimeInterval? {
        activeEntry?.remainingCountdown(at: now)
    }

    var activeCountdownProgress: Double? {
        guard let entry = activeEntry,
              let countdownDuration = entry.countdownDuration,
              countdownDuration > 0 else { return nil }
        return min(entry.duration(at: now) / countdownDuration, 1)
    }

    var timerActivityState: TimerActivityState {
        if let entry = activeEntry {
            guard let totalDuration = entry.countdownDuration,
                  let remainingDuration = entry.remainingCountdown(at: now) else {
                return .stopwatchRunning
            }
            return TrackingMath.isCountdownFinishingSoon(
                totalDuration: totalDuration,
                remainingDuration: remainingDuration
            ) ? .countdownFinishing : .countdownRunning
        }
        if pausedProject != nil { return .paused }
        if recentlyCompletedProjectName != nil { return .completed }
        return .stopped
    }

    func clearError() {
        errorMessage = nil
    }

    func dismissCountdownCompletion() {
        recentlyCompletedProjectName = nil
    }

    var notificationPreferences: TimerNotificationPreferences {
        TimerNotificationPreferences(
            isEnabled: notificationsEnabled,
            finishingSoonEnabled: countdownFinishingNotificationEnabled,
            completionEnabled: countdownCompletionNotificationEnabled,
            allocationExceededEnabled: allocationNotificationEnabled
        )
    }

    func refreshNotificationAuthorization(
        requestIfNeeded: Bool = false
    ) async {
        var state = await notificationScheduler.authorizationState()
        if requestIfNeeded, state == .notDetermined {
            let granted = await notificationScheduler.requestAuthorization()
            state = granted
                ? .authorized
                : await notificationScheduler.authorizationState()
        }

        notificationAuthorizationState = state
        if notificationsEnabled, state == .authorized {
            synchronizeScheduledNotifications()
        } else {
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
        }

        if requestIfNeeded, state == .denied {
            errorMessage = "Notifications are blocked by macOS. You can allow Weeklight notifications in System Settings."
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.notificationsEnabled)
        guard enabled else {
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
            return
        }
        prepareNotificationsIfNeeded()
    }

    func setCountdownFinishingNotificationEnabled(_ enabled: Bool) {
        countdownFinishingNotificationEnabled = enabled
        defaults.set(
            enabled,
            forKey: DefaultsKey.countdownFinishingNotificationEnabled
        )
        synchronizeScheduledNotificationsIfAuthorized()
    }

    func setCountdownCompletionNotificationEnabled(_ enabled: Bool) {
        countdownCompletionNotificationEnabled = enabled
        defaults.set(
            enabled,
            forKey: DefaultsKey.countdownCompletionNotificationEnabled
        )
        synchronizeScheduledNotificationsIfAuthorized()
    }

    func setAllocationNotificationEnabled(_ enabled: Bool) {
        allocationNotificationEnabled = enabled
        defaults.set(enabled, forKey: DefaultsKey.allocationNotificationEnabled)
        synchronizeScheduledNotificationsIfAuthorized()
    }

    // MARK: - Projects

    @discardableResult
    func createProject(
        name: String,
        colorHex: String,
        defaultWeeklyMinutes: Int
    ) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateProject(
            name: cleanedName,
            weeklyMinutes: defaultWeeklyMinutes,
            excluding: nil
        ) else { return false }

        let project = Project(
            context: context,
            name: cleanedName,
            colorHex: colorHex,
            defaultWeeklyMinutes: defaultWeeklyMinutes
        )
        _ = WeeklyAllocation(
            context: context,
            project: project,
            weekStart: selectedWeekStart,
            plannedMinutes: defaultWeeklyMinutes
        )
        return saveAndReload()
    }

    @discardableResult
    func updateProject(
        _ project: Project,
        name: String,
        colorHex: String,
        defaultWeeklyMinutes: Int,
        applyToSelectedWeek: Bool
    ) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateProject(
            name: cleanedName,
            weeklyMinutes: defaultWeeklyMinutes,
            excluding: project.id
        ) else { return false }

        project.name = cleanedName
        project.colorHex = colorHex
        project.defaultWeeklyMinutes = Int32(defaultWeeklyMinutes)
        project.updatedAt = .now

        if applyToSelectedWeek {
            setAllocationValue(
                for: project,
                weekStart: selectedWeekStart,
                minutes: defaultWeeklyMinutes
            )
        }
        return saveAndReload()
    }

    func setArchived(_ project: Project, archived: Bool, at date: Date = .now) {
        if archived, activeEntry?.project?.id == project.id {
            finishActiveTimer(at: date)
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
        }
        if archived, pausedProjectID == project.id {
            setPausedTimer(projectID: nil)
        }
        if archived, lastTrackedProjectID == project.id {
            setLastTrackedProjectID(nil)
        }

        project.isArchived = archived
        project.updatedAt = date
        _ = saveAndReload()
    }

    // MARK: - Allocations and weeks

    func moveSelectedWeek(by offset: Int) {
        selectedWeekStart = WeekMath.offset(selectedWeekStart, by: offset)
        ensureAllocations(for: selectedWeekStart)
    }

    func selectCurrentWeek() {
        selectedWeekStart = WeekMath.startOfWeek(containing: now)
        ensureAllocations(for: selectedWeekStart)
    }

    func allocation(for project: Project, weekStart: Date) -> WeeklyAllocation? {
        allocations.first {
            $0.project?.id == project.id && $0.weekStart == weekStart
        }
    }

    func allocationMinutes(for project: Project, weekStart: Date) -> Int {
        if let allocation = allocation(for: project, weekStart: weekStart) {
            return Int(allocation.plannedMinutes)
        }
        return Int(project.defaultWeeklyMinutes)
    }

    func updateAllocation(
        for project: Project,
        weekStart: Date,
        minutes: Int
    ) {
        guard (0...(168 * 60)).contains(minutes) else {
            errorMessage = "Weekly allocation must be between 0 and 168 hours."
            return
        }
        setAllocationValue(for: project, weekStart: weekStart, minutes: minutes)
        _ = saveAndReload()
    }

    func ensureAllocations(for weekStart: Date) {
        var inserted = false
        for project in activeProjects where allocation(for: project, weekStart: weekStart) == nil {
            _ = WeeklyAllocation(
                context: context,
                project: project,
                weekStart: weekStart,
                plannedMinutes: Int(project.defaultWeeklyMinutes)
            )
            inserted = true
        }
        if inserted {
            _ = saveAndReload()
        }
    }

    func projectsVisible(in weekStart: Date) -> [Project] {
        let interval = WeekMath.interval(containing: weekStart)
        return projects.filter { project in
            if !project.isArchived { return true }
            let hasAllocation = Int(
                allocation(for: project, weekStart: weekStart)?.plannedMinutes ?? 0
            ) > 0
            let hasTime = TrackingMath.trackedDuration(
                for: project.id,
                entries: entries,
                interval: interval,
                now: now
            ) > 0
            return hasAllocation || hasTime
        }
    }

    func progress(for project: Project, weekStart: Date) -> ProjectProgress {
        let interval = WeekMath.interval(containing: weekStart)
        let tracked = TrackingMath.trackedDuration(
            for: project.id,
            entries: entries,
            interval: interval,
            now: now
        )
        return ProjectProgress(
            plannedMinutes: allocationMinutes(for: project, weekStart: weekStart),
            trackedSeconds: tracked
        )
    }

    func totalProgress(for weekStart: Date) -> ProjectProgress {
        let visibleProjects = projectsVisible(in: weekStart)
        let planned = visibleProjects.reduce(0) {
            $0 + allocationMinutes(for: $1, weekStart: weekStart)
        }
        let tracked = TrackingMath.trackedDuration(
            entries: entries,
            interval: WeekMath.interval(containing: weekStart),
            now: now
        )
        return ProjectProgress(plannedMinutes: planned, trackedSeconds: tracked)
    }

    func totalAllocatedMinutes(for weekStart: Date) -> Int {
        projectsVisible(in: weekStart).reduce(0) {
            $0 + allocationMinutes(for: $1, weekStart: weekStart)
        }
    }

    func updateWeeklyCapacity(minutes: Int) {
        guard (60...(168 * 60)).contains(minutes) else {
            errorMessage = "Weekly capacity must be between 1 and 168 hours."
            return
        }
        weeklyCapacityMinutes = minutes
        defaults.set(minutes, forKey: DefaultsKey.weeklyCapacityMinutes)
    }

    // MARK: - Timer

    @discardableResult
    func startTimer(
        for project: Project,
        countdownSeconds: TimeInterval? = nil,
        noteMarkdown: String = "",
        tagNames: [String] = [],
        at date: Date = .now
    ) -> Bool {
        guard !project.isArchived else {
            errorMessage = "Archived projects cannot be tracked."
            return false
        }
        if let countdownSeconds,
           !(60...(24 * 60 * 60)).contains(countdownSeconds) {
            errorMessage = "Countdown duration must be between 1 minute and 24 hours."
            return false
        }

        if activeEntry?.project?.id == project.id,
           activeEntry?.countdownDuration == countdownSeconds {
            return true
        }

        guard let metadata = cleanFocusMetadata(
            noteMarkdown: noteMarkdown,
            tagNames: tagNames
        ) else { return false }

        return startTimerSegment(
            for: project,
            countdownSeconds: countdownSeconds,
            continuing: nil,
            metadata: metadata,
            at: date
        )
    }

    private func startTimerSegment(
        for project: Project,
        countdownSeconds: TimeInterval?,
        continuing session: FocusSession?,
        metadata: (note: String, tags: [String]),
        at date: Date
    ) -> Bool {

        finishActiveTimer(at: date)
        setPausedTimer(projectID: nil)
        setLastTrackedProjectID(project.id)
        recentlyCompletedProjectName = nil

        let focusSession = session ?? createFocusSession(
            project: project,
            noteMarkdown: metadata.note,
            tagNames: metadata.tags,
            at: date
        )
        focusSession.project = project
        focusSession.updatedAt = date

        let entry = TimeEntry(
            context: context,
            project: project,
            focusSession: focusSession,
            startedAt: date,
            note: focusSession.noteMarkdown,
            countdownDuration: countdownSeconds
        )
        activeEntry = entry
        let didSave = saveAndReload()
        if didSave {
            prepareNotificationsIfNeeded()
        }
        return didSave
    }

    func pauseTimer(at date: Date = .now) {
        guard let entry = activeEntry,
              let projectID = entry.project?.id else { return }
        let remainingCountdown = entry.remainingCountdown(at: date)
        if entry.isCountdown, remainingCountdown == 0 {
            completeCountdownIfNeeded(at: date, playsSound: true)
            return
        }
        finishActiveTimer(at: date)
        setPausedTimer(
            projectID: projectID,
            countdownSeconds: remainingCountdown,
            focusSessionID: entry.focusSession?.id
        )
        notificationScheduler.cancelScheduledTimerNotifications()
        scheduledNotificationWeekStart = nil
        _ = saveAndReload()
    }

    func stopTimer(at date: Date = .now) {
        let stoppedProjectID = activeEntry?.project?.id ?? pausedProjectID
        finishActiveTimer(at: date)
        setPausedTimer(projectID: nil)
        setLastTrackedProjectID(stoppedProjectID)
        notificationScheduler.cancelScheduledTimerNotifications()
        scheduledNotificationWeekStart = nil
        _ = saveAndReload()
    }

    func resumeTimer(at date: Date = .now) {
        guard let pausedProject else { return }
        let session = pausedFocusSession
        _ = startTimerSegment(
            for: pausedProject,
            countdownSeconds: pausedCountdownSeconds,
            continuing: session,
            metadata: (
                note: session?.noteMarkdown ?? "",
                tags: session?.sortedTags.map(\.name) ?? []
            ),
            at: date
        )
    }

    func refreshTimer(
        at date: Date = .now,
        playsCompletionSound: Bool = true
    ) {
        now = date
        let currentWeekStart = WeekMath.startOfWeek(containing: date)
        if notificationAuthorizationState == .authorized,
           activeEntry != nil,
           scheduledNotificationWeekStart != currentWeekStart {
            synchronizeScheduledNotifications()
        }
        completeCountdownIfNeeded(
            at: date,
            playsSound: playsCompletionSound
        )
    }

    // MARK: - Focus sessions and time entries

    func focusSessions(in weekStart: Date) -> [FocusSession] {
        let entryIDs = Set(entries(in: weekStart).map(\.id))
        return focusSessions.filter { session in
            session.sortedEntries.contains { entryIDs.contains($0.id) }
        }
    }

    func duration(
        for session: FocusSession,
        in weekStart: Date
    ) -> TimeInterval {
        TrackingMath.trackedDuration(
            entries: session.sortedEntries,
            interval: WeekMath.interval(containing: weekStart),
            now: now
        )
    }

    @discardableResult
    func updateFocusSession(
        _ session: FocusSession,
        noteMarkdown: String,
        tagNames: [String]
    ) -> Bool {
        guard let metadata = cleanFocusMetadata(
            noteMarkdown: noteMarkdown,
            tagNames: tagNames
        ) else { return false }

        applyFocusMetadata(metadata, to: session)
        return saveAndReload()
    }

    func deleteFocusSession(_ session: FocusSession) {
        guard !session.isRunning else {
            errorMessage = "Stop the running timer before deleting its session."
            return
        }
        if session.id == pausedFocusSessionID {
            setPausedTimer(projectID: nil)
        }
        context.delete(session)
        _ = saveAndReload()
    }

    func entries(in weekStart: Date) -> [TimeEntry] {
        let interval = WeekMath.interval(containing: weekStart)
        return entries.filter { entry in
            let end = entry.endedAt ?? now
            return TrackingMath.intervalsOverlap(
                start: entry.startedAt,
                end: end,
                otherStart: interval.start,
                otherEnd: interval.end
            )
        }
    }

    @discardableResult
    func addManualEntry(
        project: Project,
        start: Date,
        end: Date,
        note: String,
        tagNames: [String] = []
    ) -> Bool {
        guard validateEntry(start: start, end: end, excluding: nil) else {
            return false
        }
        guard let metadata = cleanFocusMetadata(
            noteMarkdown: note,
            tagNames: tagNames
        ) else { return false }

        let session = createFocusSession(
            project: project,
            noteMarkdown: metadata.note,
            tagNames: metadata.tags,
            at: start
        )

        _ = TimeEntry(
            context: context,
            project: project,
            focusSession: session,
            startedAt: start,
            endedAt: end,
            note: metadata.note,
            source: .manual
        )
        return saveAndReload()
    }

    @discardableResult
    func updateEntry(
        _ entry: TimeEntry,
        project: Project,
        start: Date,
        end: Date,
        note: String,
        tagNames: [String]? = nil
    ) -> Bool {
        guard !entry.isRunning else {
            errorMessage = "Stop the running timer before editing it."
            return false
        }
        guard validateEntry(start: start, end: end, excluding: entry.id) else {
            return false
        }

        let existingSession = entry.focusSession
        let effectiveTagNames = tagNames
            ?? existingSession?.sortedTags.map(\.name)
            ?? []
        guard let metadata = cleanFocusMetadata(
            noteMarkdown: note,
            tagNames: effectiveTagNames
        ) else { return false }

        let session = existingSession ?? createFocusSession(
            project: project,
            noteMarkdown: metadata.note,
            tagNames: metadata.tags,
            at: entry.createdAt
        )

        session.project = project
        for segment in session.sortedEntries {
            segment.project = project
            segment.updatedAt = .now
        }
        applyFocusMetadata(metadata, to: session)

        entry.project = project
        entry.focusSession = session
        entry.startedAt = start
        entry.endedAt = end
        entry.note = metadata.note
        entry.updatedAt = .now
        return saveAndReload()
    }

    @discardableResult
    func splitEntry(
        _ entry: TimeEntry,
        at splitDate: Date,
        secondProject: Project,
        secondNote: String,
        secondTagNames: [String]? = nil
    ) -> Bool {
        guard !entry.isRunning, let originalEnd = entry.endedAt else {
            errorMessage = "Stop the running timer before splitting it."
            return false
        }
        guard splitDate > entry.startedAt, splitDate < originalEnd else {
            errorMessage = "The split time must be inside the session."
            return false
        }
        guard validateEntry(
            start: entry.startedAt,
            end: splitDate,
            excluding: entry.id
        ), validateEntry(
            start: splitDate,
            end: originalEnd,
            excluding: entry.id
        ) else {
            return false
        }

        let originalCountdownDuration = entry.countdownDuration
        let firstDuration = splitDate.timeIntervalSince(entry.startedAt)
        let secondCountdownDuration = originalCountdownDuration.flatMap {
            let remaining = $0 - firstDuration
            return remaining > 0 ? remaining : nil
        }
        let inheritedTags = entry.focusSession?.sortedTags.map(\.name) ?? []
        guard let secondMetadata = cleanFocusMetadata(
            noteMarkdown: secondNote,
            tagNames: secondTagNames ?? inheritedTags
        ) else { return false }

        entry.endedAt = splitDate
        entry.updatedAt = .now
        if let originalCountdownDuration {
            entry.countdownDuration = min(originalCountdownDuration, firstDuration)
        }

        let secondSession = createFocusSession(
            project: secondProject,
            noteMarkdown: secondMetadata.note,
            tagNames: secondMetadata.tags,
            at: splitDate
        )

        _ = TimeEntry(
            context: context,
            project: secondProject,
            focusSession: secondSession,
            startedAt: splitDate,
            endedAt: originalEnd,
            note: secondMetadata.note,
            source: entry.source,
            countdownDuration: secondCountdownDuration
        )
        return saveAndReload()
    }

    func deleteEntry(_ entry: TimeEntry) {
        guard !entry.isRunning else {
            errorMessage = "Stop the running timer before deleting it."
            return
        }
        let session = entry.focusSession
        let deletesSession = session?.sortedEntries.count == 1
        if deletesSession, session?.id == pausedFocusSessionID {
            setPausedTimer(projectID: nil)
        }
        context.delete(entry)
        if deletesSession, let session {
            context.delete(session)
        }
        _ = saveAndReload()
    }

    // MARK: - System integration

    func setLaunchAtLogin(_ enabled: Bool) {
        refreshLaunchAtLoginState()

        if enabled, launchAtLoginState == .enabled {
            return
        }
        if enabled, launchAtLoginState == .requiresApproval {
            launchAtLoginController.openSystemSettings()
            return
        }
        if !enabled, !launchAtLoginState.isRegistered {
            return
        }

        do {
            if enabled {
                try launchAtLoginController.register()
            } else {
                try launchAtLoginController.unregister()
            }
            refreshLaunchAtLoginState()
        } catch {
            refreshLaunchAtLoginState()
            switch launchAtLoginState {
            case .requiresApproval:
                errorMessage = "macOS requires approval before Weeklight can launch at login. Open Login Items in System Settings to allow it."
            case .unavailable:
                errorMessage = "Weeklight could not register as a login item. Run the signed Weeklight.app bundle from a stable location and try again."
            case .disabled, .enabled:
                errorMessage = "Launch at login could not be updated: \(error.localizedDescription)"
            }
        }
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginState = launchAtLoginController.state
        launchAtLoginEnabled = launchAtLoginState.isRegistered
    }

    func openLoginItemsSettings() {
        launchAtLoginController.openSystemSettings()
    }

    var appIsInApplicationsFolder: Bool {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        let applicationDirectories = [
            FileManager.default.urls(
                for: .applicationDirectory,
                in: .localDomainMask
            ).first,
            FileManager.default.urls(
                for: .applicationDirectory,
                in: .userDomainMask
            ).first
        ].compactMap { $0?.standardizedFileURL.path }

        return applicationDirectories.contains { directory in
            bundlePath == directory || bundlePath.hasPrefix(directory + "/")
        }
    }

    // MARK: - Private

    private func beginTicker() {
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refreshTimer()
            }
        }
    }

    private func reload() {
        do {
            projects = try context.fetch(NSFetchRequest<Project>(entityName: "Project"))
                .sorted { lhs, rhs in
                    if lhs.isArchived != rhs.isArchived {
                        return !lhs.isArchived
                    }
                    return lhs.createdAt < rhs.createdAt
                }
            allocations = try context.fetch(
                NSFetchRequest<WeeklyAllocation>(entityName: "WeeklyAllocation")
            )
            entries = try context.fetch(NSFetchRequest<TimeEntry>(entityName: "TimeEntry"))
                .sorted { $0.startedAt > $1.startedAt }
            focusSessions = try context.fetch(
                NSFetchRequest<FocusSession>(entityName: "FocusSession")
            ).sorted {
                ($0.startedAt ?? $0.createdAt) > ($1.startedAt ?? $1.createdAt)
            }
            focusTags = try context.fetch(
                NSFetchRequest<FocusTag>(entityName: "FocusTag")
            ).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            activeEntry = entries.first(where: \.isRunning)
        } catch {
            errorMessage = "Stored data could not be loaded: \(error.localizedDescription)"
        }
    }

    private func recoverActiveTimer(at date: Date) {
        let runningEntries = entries.filter(\.isRunning)
            .sorted { $0.startedAt > $1.startedAt }
        guard let newest = runningEntries.first else {
            activeEntry = nil
            return
        }

        activeEntry = newest
        setPausedTimer(projectID: nil)

        if runningEntries.count > 1 {
            for olderEntry in runningEntries.dropFirst() {
                olderEntry.endedAt = max(olderEntry.startedAt, newest.startedAt)
                olderEntry.updatedAt = date
            }
            _ = saveAndReload()
            activeEntry = entries.first(where: \.isRunning)
        }
        completeCountdownIfNeeded(at: date, playsSound: false)
    }

    private func recoverPausedFocusSessionIfNeeded() {
        guard let pausedProjectID,
              pausedFocusSessionID == nil,
              let session = focusSessions.first(where: {
                  $0.project?.id == pausedProjectID && !$0.isRunning
              }) else { return }

        setPausedTimer(
            projectID: pausedProjectID,
            countdownSeconds: pausedCountdownSeconds,
            focusSessionID: session.id
        )
    }

    private func finishActiveTimer(at date: Date) {
        guard let entry = activeEntry else { return }
        let effectiveEnd: Date
        if let scheduledEnd = entry.scheduledCountdownEnd {
            effectiveEnd = min(date, scheduledEnd)
        } else {
            effectiveEnd = date
        }
        entry.endedAt = max(entry.startedAt, effectiveEnd)
        entry.updatedAt = date
        entry.focusSession?.updatedAt = date
        activeEntry = nil
    }

    private func setPausedTimer(
        projectID: UUID?,
        countdownSeconds: TimeInterval? = nil,
        focusSessionID: UUID? = nil
    ) {
        pausedProjectID = projectID
        pausedCountdownSeconds = countdownSeconds
        pausedFocusSessionID = focusSessionID
        if let projectID {
            defaults.set(projectID.uuidString, forKey: DefaultsKey.pausedProjectID)
        } else {
            defaults.removeObject(forKey: DefaultsKey.pausedProjectID)
        }
        if let countdownSeconds, countdownSeconds > 0 {
            defaults.set(countdownSeconds, forKey: DefaultsKey.pausedCountdownSeconds)
        } else {
            defaults.removeObject(forKey: DefaultsKey.pausedCountdownSeconds)
        }
        if let focusSessionID {
            defaults.set(
                focusSessionID.uuidString,
                forKey: DefaultsKey.pausedFocusSessionID
            )
        } else {
            defaults.removeObject(forKey: DefaultsKey.pausedFocusSessionID)
        }
    }

    private func completeCountdownIfNeeded(
        at date: Date,
        playsSound: Bool
    ) {
        guard let entry = activeEntry,
              let scheduledEnd = entry.scheduledCountdownEnd,
              date >= scheduledEnd else { return }

        let completedProjectName = entry.project?.name ?? "Project"
        let completedProjectID = entry.project?.id
        entry.endedAt = scheduledEnd
        entry.updatedAt = date
        entry.focusSession?.updatedAt = date
        activeEntry = nil
        setPausedTimer(projectID: nil)
        setLastTrackedProjectID(completedProjectID)
        recentlyCompletedProjectName = completedProjectName
        _ = saveAndReload(reschedulesNotifications: false)

        let completionNotificationWillSound = notificationsEnabled
            && countdownCompletionNotificationEnabled
            && notificationAuthorizationState == .authorized
        if playsSound, !completionNotificationWillSound {
            NSSound.beep()
        }
    }

    private func setLastTrackedProjectID(_ id: UUID?) {
        lastTrackedProjectID = id
        if let id {
            defaults.set(id.uuidString, forKey: DefaultsKey.lastTrackedProjectID)
        } else {
            defaults.removeObject(forKey: DefaultsKey.lastTrackedProjectID)
        }
    }

    private func prepareNotificationsIfNeeded() {
        guard notificationsEnabled else {
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
            return
        }

        switch notificationAuthorizationState {
        case .authorized:
            synchronizeScheduledNotifications()
        case .denied:
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
        case .unknown, .notDetermined:
            Task { @MainActor [weak self] in
                await self?.refreshNotificationAuthorization(requestIfNeeded: true)
            }
        }
    }

    private func synchronizeScheduledNotificationsIfAuthorized() {
        guard notificationAuthorizationState == .authorized else { return }
        synchronizeScheduledNotifications()
    }

    private func synchronizeScheduledNotifications() {
        guard notificationsEnabled,
              notificationAuthorizationState == .authorized,
              let entry = activeEntry,
              let project = entry.project else {
            notificationScheduler.cancelScheduledTimerNotifications()
            scheduledNotificationWeekStart = nil
            return
        }

        let currentWeekStart = WeekMath.startOfWeek(containing: now)
        let currentWeek = WeekMath.interval(containing: currentWeekStart)
        let progress = progress(for: project, weekStart: currentWeekStart)
        let plannedSeconds = TimeInterval(progress.plannedMinutes * 60)
        let allocationRemaining = plannedSeconds > 0
            ? plannedSeconds - progress.trackedSeconds
            : nil
        let schedule = TimerNotificationPolicy.schedule(
            countdownDuration: entry.countdownDuration,
            elapsedDuration: entry.duration(at: now),
            allocationRemaining: allocationRemaining,
            secondsUntilWeekEnds: currentWeek.end.timeIntervalSince(now),
            preferences: notificationPreferences
        )

        notificationScheduler.replaceScheduledNotifications(
            with: schedule,
            projectName: project.name
        )
        scheduledNotificationWeekStart = currentWeekStart
    }

    private func cleanFocusMetadata(
        noteMarkdown: String,
        tagNames: [String]
    ) -> (note: String, tags: [String])? {
        let note = FocusMetadata.cleanNote(noteMarkdown)
        guard note.count <= FocusMetadata.maximumNoteLength else {
            errorMessage = "Session notes cannot exceed \(FocusMetadata.maximumNoteLength.formatted()) characters."
            return nil
        }

        let tags = FocusMetadata.uniqueCleanTags(tagNames)
        guard tags.count <= FocusMetadata.maximumTagCount else {
            errorMessage = "A session can have up to \(FocusMetadata.maximumTagCount) tags."
            return nil
        }
        guard let oversizedTag = tags.first(where: {
            $0.count > FocusMetadata.maximumTagLength
        }) else {
            return (note, tags)
        }
        errorMessage = "The tag “\(oversizedTag)” exceeds \(FocusMetadata.maximumTagLength) characters."
        return nil
    }

    private func createFocusSession(
        project: Project,
        noteMarkdown: String,
        tagNames: [String],
        at date: Date
    ) -> FocusSession {
        let session = FocusSession(
            context: context,
            project: project,
            noteMarkdown: noteMarkdown,
            createdAt: date,
            updatedAt: date
        )
        applyFocusMetadata((noteMarkdown, tagNames), to: session)
        return session
    }

    private func applyFocusMetadata(
        _ metadata: (note: String, tags: [String]),
        to session: FocusSession
    ) {
        session.noteMarkdown = metadata.note
        session.updatedAt = .now

        let resolvedTags = resolveTags(named: metadata.tags)
        let relationship = session.mutableSetValue(forKey: "tags")
        relationship.removeAllObjects()
        for tag in resolvedTags {
            relationship.add(tag)
        }

        for entry in session.sortedEntries {
            entry.note = metadata.note
            entry.updatedAt = .now
        }
    }

    private func resolveTags(named names: [String]) -> [FocusTag] {
        var availableTags = focusTags
        availableTags.append(
            contentsOf: context.insertedObjects.compactMap { $0 as? FocusTag }
        )

        return names.map { name in
            let normalizedName = FocusMetadata.normalizedTag(name)
            if let existing = availableTags.first(where: {
                $0.normalizedName == normalizedName
            }) {
                existing.updatedAt = .now
                return existing
            }

            let tag = FocusTag(
                context: context,
                name: name,
                normalizedName: normalizedName
            )
            availableTags.append(tag)
            return tag
        }
    }

    private func setAllocationValue(
        for project: Project,
        weekStart: Date,
        minutes: Int
    ) {
        if let allocation = allocation(for: project, weekStart: weekStart) {
            allocation.plannedMinutes = Int32(minutes)
            allocation.updatedAt = .now
        } else {
            _ = WeeklyAllocation(
                context: context,
                project: project,
                weekStart: weekStart,
                plannedMinutes: minutes
            )
        }
    }

    private func validateProject(
        name: String,
        weeklyMinutes: Int,
        excluding projectID: UUID?
    ) -> Bool {
        guard !name.isEmpty else {
            errorMessage = "Project name cannot be empty."
            return false
        }
        guard (0...(168 * 60)).contains(weeklyMinutes) else {
            errorMessage = "Weekly allocation must be between 0 and 168 hours."
            return false
        }
        let duplicate = projects.contains {
            $0.id != projectID
                && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !duplicate else {
            errorMessage = "A project with this name already exists."
            return false
        }
        return true
    }

    private func validateEntry(
        start: Date,
        end: Date,
        excluding entryID: UUID?
    ) -> Bool {
        guard end > start else {
            errorMessage = "The end time must be later than the start time."
            return false
        }
        guard end <= Date.now.addingTimeInterval(60) else {
            errorMessage = "Time entries cannot end in the future."
            return false
        }

        let overlaps = entries.contains { entry in
            guard entry.id != entryID else { return false }
            let entryEnd = entry.endedAt ?? Date.now
            return TrackingMath.intervalsOverlap(
                start: start,
                end: end,
                otherStart: entry.startedAt,
                otherEnd: entryEnd
            )
        }
        guard !overlaps else {
            errorMessage = "This entry overlaps another tracked session."
            return false
        }
        return true
    }

    @discardableResult
    private func saveAndReload(
        reschedulesNotifications: Bool = true
    ) -> Bool {
        do {
            try context.save()
            reload()
            if reschedulesNotifications {
                synchronizeScheduledNotificationsIfAuthorized()
            }
            return true
        } catch {
            context.rollback()
            reload()
            errorMessage = "Changes could not be saved: \(error.localizedDescription)"
            return false
        }
    }
}
