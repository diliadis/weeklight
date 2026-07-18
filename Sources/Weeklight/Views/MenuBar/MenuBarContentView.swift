import AppKit
import SwiftUI

private enum TimerStartMode: String, CaseIterable, Identifiable {
    case stopwatch
    case countdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stopwatch: "Stopwatch"
        case .countdown: "Countdown"
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var focusDetailsCoordinator: FocusDetailsCoordinator
    @Environment(\.openWindow) private var openWindow
    @State private var selectedProjectID: UUID?
    @State private var timerStartMode: TimerStartMode = .stopwatch
    @State private var countdownMinutes = 30.0

    private var currentWeekStart: Date {
        WeekMath.startOfWeek(containing: appModel.now)
    }

    private var totalProgress: ProjectProgress {
        appModel.totalProgress(for: currentWeekStart)
    }

    private var selectedProject: Project? {
        let id = selectedProjectID ?? appModel.activeProjects.first?.id
        return appModel.activeProjects.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if let completedProject = appModel.recentlyCompletedProjectName {
                    completionBanner(projectName: completedProject)
                }

                if let entry = appModel.activeEntry,
                   let project = entry.project {
                    activeTimer(project: project)
                } else if let project = appModel.pausedProject {
                    pausedTimer(project: project)
                } else if appModel.activeProjects.isEmpty {
                    ContentUnavailableView(
                        "No projects",
                        systemImage: "square.stack.3d.up",
                        description: Text("Open the dashboard to create one.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    startTimer
                }

                if !appModel.activeProjects.isEmpty {
                    projectProgress
                }
            }
            .padding(16)

            Divider()
            footer
        }
        .frame(width: 350)
        .onAppear {
            appModel.ensureAllocations(for: currentWeekStart)
            if selectedProjectID == nil {
                selectedProjectID = appModel.activeProjects.first?.id
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("This week", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                Text("\(DurationText.compact(totalProgress.trackedSeconds)) / \(DurationText.hours(totalProgress.plannedMinutes))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(totalProgress.fractionCompleted, 1))
        }
        .padding(16)
    }

    private func activeTimer(project: Project) -> some View {
        let isCountdown = appModel.activeRemainingDuration != nil
        let displayedDuration = appModel.activeRemainingDuration ?? appModel.activeDuration

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProjectMark(project: project, size: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeStatusTitle(isCountdown: isCountdown))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                Text(
                    isCountdown
                        ? DurationText.countdownClock(displayedDuration)
                        : DurationText.clock(displayedDuration)
                )
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            if let countdownProgress = appModel.activeCountdownProgress {
                ProgressView(value: countdownProgress)
                    .tint(Color(projectHex: project.colorHex))
                    .accessibilityLabel("Countdown progress")
            }

            if let session = appModel.activeFocusSession {
                focusMetadataSummary(session)
            }

            HStack(spacing: 8) {
                Button {
                    appModel.pauseTimer()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    appModel.stopTimer()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Menu {
                ForEach(appModel.activeProjects.filter { $0.id != project.id }) { candidate in
                    Button {
                        selectedProjectID = candidate.id
                        appModel.startTimer(for: candidate)
                    } label: {
                        Text(candidate.name)
                    }
                }
            } label: {
                Label("Switch project", systemImage: "arrow.triangle.swap")
                    .frame(maxWidth: .infinity)
            }
            .disabled(appModel.activeProjects.count < 2)

            if let session = appModel.activeFocusSession {
                Button {
                    focusDetailsCoordinator.showSession(session, using: appModel)
                } label: {
                    Label("Edit notes and tags", systemImage: "note.text")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func pausedTimer(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProjectMark(project: project, size: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(project.name)
                        .font(.headline)
                    if let remaining = appModel.pausedCountdownSeconds {
                        Text("\(DurationText.compact(remaining)) remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let session = appModel.pausedFocusSession {
                focusMetadataSummary(session)
            }

            HStack(spacing: 8) {
                Button {
                    appModel.resumeTimer()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appModel.stopTimer()
                } label: {
                    Text("Finish")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }


            if let session = appModel.pausedFocusSession {
                Button {
                    focusDetailsCoordinator.showSession(session, using: appModel)
                } label: {
                    Label("Edit notes and tags", systemImage: "note.text")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var startTimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start tracking")
                .font(.headline)

            Picker("Project", selection: projectSelection) {
                ForEach(appModel.activeProjects) { project in
                    Text(project.name).tag(project.id)
                }
            }
            .labelsHidden()

            Picker("Timer type", selection: $timerStartMode) {
                ForEach(TimerStartMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if timerStartMode == .countdown {
                HStack {
                    Label("Duration", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        value: $countdownMinutes,
                        in: 5...480,
                        step: 5
                    ) {
                        Text(DurationText.compact(countdownMinutes * 60))
                            .monospacedDigit()
                            .frame(minWidth: 48, alignment: .trailing)
                    }
                    .accessibilityLabel("Countdown duration")
                }
            }

            Button {
                focusDetailsCoordinator.showTimerDraft(using: appModel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: timerDraftIsEmpty
                        ? "note.text.badge.plus"
                        : "note.text")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timerDraftIsEmpty
                            ? "Add notes and tags"
                            : "Edit notes and tags")
                        if !timerDraftIsEmpty {
                            Text(draftDetailsSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            Button {
                guard let selectedProject else { return }
                let didStart = appModel.startTimer(
                    for: selectedProject,
                    countdownSeconds: timerStartMode == .countdown
                        ? countdownMinutes * 60
                        : nil,
                    noteMarkdown: focusDetailsCoordinator.timerDraftNoteMarkdown,
                    tagNames: focusDetailsCoordinator.timerDraftTagNames
                )
                if didStart {
                    focusDetailsCoordinator.clearTimerDraft()
                }
            } label: {
                Label(
                    timerStartMode == .countdown
                        ? "Start \(DurationText.compact(countdownMinutes * 60)) countdown"
                        : "Start stopwatch",
                    systemImage: "play.fill"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var projectProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allocation")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(appModel.activeProjects.prefix(5)) { project in
                let progress = appModel.progress(for: project, weekStart: currentWeekStart)
                VStack(spacing: 5) {
                    HStack(spacing: 7) {
                        ProjectMark(project: project, size: 8)
                        Text(project.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(DurationText.compact(progress.trackedSeconds)) / \(DurationText.hours(progress.plannedMinutes))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(progress.fractionCompleted, 1))
                        .tint(Color(projectHex: project.colorHex))
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openDashboard()
            } label: {
                Label("Open dashboard", systemImage: "macwindow")
            }
            .buttonStyle(.plain)

            Spacer()

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit Weeklight")
        }
        .padding(13)
    }

    private func completionBanner(projectName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Countdown complete")
                    .font(.headline)
                Text(projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appModel.dismissCountdownCompletion()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func activeStatusTitle(isCountdown: Bool) -> String {
        if appModel.timerActivityState == .countdownFinishing {
            return "Finishing soon"
        }
        return isCountdown ? "Time remaining" : "Running"
    }

    @ViewBuilder
    private func focusMetadataSummary(_ session: FocusSession) -> some View {
        let summary = FocusMetadata.summary(from: session.noteMarkdown, limit: 85)
        if !summary.isEmpty || !session.sortedTags.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !session.sortedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(session.sortedTags) { tag in
                                TagPill(name: tag.name)
                            }
                        }
                    }
                }
            }
        }
    }

    private var draftDetailsSummary: String {
        let summary = FocusMetadata.summary(
            from: focusDetailsCoordinator.timerDraftNoteMarkdown,
            limit: 55
        )
        let tags = focusDetailsCoordinator.timerDraftTagNames
            .map { "#\($0)" }
            .joined(separator: " ")
        return [summary, tags].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var timerDraftIsEmpty: Bool {
        focusDetailsCoordinator.timerDraftNoteMarkdown.isEmpty
            && focusDetailsCoordinator.timerDraftTagNames.isEmpty
    }

    private var projectSelection: Binding<UUID> {
        Binding(
            get: { selectedProjectID ?? appModel.activeProjects.first?.id ?? UUID() },
            set: { selectedProjectID = $0 }
        )
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        NSApp.activate(ignoringOtherApps: true)
    }
}
