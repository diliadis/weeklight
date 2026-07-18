import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingEntryEditor = false

    private var progress: ProjectProgress {
        appModel.totalProgress(for: appModel.selectedWeekStart)
    }

    private var capacityRemaining: Int {
        appModel.weeklyCapacityMinutes
            - appModel.totalAllocatedMinutes(for: appModel.selectedWeekStart)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if appModel.activeProjects.isEmpty && appModel.entries.isEmpty {
                    ContentUnavailableView(
                        "Create your first project",
                        systemImage: "sparkles",
                        description: Text("Projects connect your weekly plan to every tracked session.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    metrics
                    weeklyProgress
                    recentActivity
                }
            }
            .padding(26)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingEntryEditor = true
                } label: {
                    Label("Add time", systemImage: "plus")
                }
                .disabled(appModel.activeProjects.isEmpty)
                WeekNavigation()
            }
        }
        .sheet(isPresented: $showingEntryEditor) {
            TimeEntryEditorView(entry: nil)
                .environmentObject(appModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your week")
                .font(.largeTitle.bold())
            Text("Stay aware of where your time is going without breaking focus.")
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: some View {
        HStack(spacing: 14) {
            MetricCard(
                title: "Logged",
                value: DurationText.compact(progress.trackedSeconds),
                detail: "Across all projects",
                systemImage: "clock.fill"
            )
            MetricCard(
                title: "Remaining",
                value: DurationText.compact(progress.remainingSeconds),
                detail: progress.plannedMinutes == 0 ? "No time planned" : "Against this week’s plan",
                systemImage: "hourglass"
            )
            MetricCard(
                title: "Plan",
                value: DurationText.hours(progress.plannedMinutes),
                detail: capacityDetail,
                systemImage: "calendar.badge.clock"
            )
        }
    }

    private var capacityDetail: String {
        if capacityRemaining < 0 {
            return "\(DurationText.hours(abs(capacityRemaining))) over capacity"
        }
        return "\(DurationText.hours(capacityRemaining)) unallocated"
    }

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly allocation")
                    .font(.title3.bold())
                Spacer()
                if capacityRemaining < 0 {
                    Label("Over capacity", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(appModel.projectsVisible(in: appModel.selectedWeekStart).enumerated()), id: \.element.id) { index, project in
                    AllocationRow(project: project, weekStart: appModel.selectedWeekStart)
                    if index < appModel.projectsVisible(in: appModel.selectedWeekStart).count - 1 {
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var recentActivity: some View {
        let recent = Array(
            appModel.focusSessions(in: appModel.selectedWeekStart)
                .filter { !$0.isRunning }
                .prefix(5)
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent activity")
                    .font(.title3.bold())
                Spacer()
                Button("Add time") {
                    showingEntryEditor = true
                }
                .buttonStyle(.borderless)
            }

            if recent.isEmpty {
                Text("Tracked sessions will appear here.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, session in
                        FocusSessionRow(
                            session: session,
                            weekStart: appModel.selectedWeekStart,
                            showsActions: false
                        )
                        if index < recent.count - 1 {
                            Divider().padding(.leading, 38)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct AllocationRow: View {
    @EnvironmentObject private var appModel: AppModel
    let project: Project
    let weekStart: Date

    private var progress: ProjectProgress {
        appModel.progress(for: project, weekStart: weekStart)
    }

    var body: some View {
        HStack(spacing: 12) {
            ProjectMark(project: project, size: 11)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(project.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(DurationText.compact(progress.trackedSeconds)) / \(DurationText.hours(progress.plannedMinutes))")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(progress.fractionCompleted, 1))
                    .tint(Color(projectHex: project.colorHex))
            }

            Stepper(
                "Allocation for \(project.name)",
                value: Binding(
                    get: { Double(progress.plannedMinutes) / 60 },
                    set: { value in
                        appModel.updateAllocation(
                            for: project,
                            weekStart: weekStart,
                            minutes: Int((value * 60).rounded())
                        )
                    }
                ),
                in: 0...168,
                step: 0.5
            )
            .labelsHidden()
            .help("Adjust weekly allocation")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
