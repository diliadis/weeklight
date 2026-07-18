import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingNewProject = false
    @State private var editingProject: Project?
    @State private var projectToArchive: Project?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Projects")
                        .font(.largeTitle.bold())
                    Text("Set a default weekly plan, then adjust individual weeks from Overview.")
                        .foregroundStyle(.secondary)
                }

                if appModel.activeProjects.isEmpty {
                    ContentUnavailableView(
                        "No active projects",
                        systemImage: "square.stack.3d.up",
                        description: Text("Add a project to start planning and tracking time.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appModel.activeProjects.enumerated()), id: \.element.id) { index, project in
                            ProjectRow(
                                project: project,
                                editAction: { editingProject = project },
                                archiveAction: { projectToArchive = project }
                            )
                            if index < appModel.activeProjects.count - 1 {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if !appModel.archivedProjects.isEmpty {
                    DisclosureGroup("Archived projects") {
                        VStack(spacing: 0) {
                            ForEach(appModel.archivedProjects) { project in
                                HStack(spacing: 12) {
                                    ProjectMark(project: project)
                                    Text(project.name)
                                    Spacer()
                                    Button("Restore") {
                                        appModel.setArchived(project, archived: false)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(26)
        }
        .navigationTitle("Projects")
        .toolbar {
            Button {
                showingNewProject = true
            } label: {
                Label("New project", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectEditorView(project: nil)
                .environmentObject(appModel)
        }
        .sheet(item: $editingProject) { project in
            ProjectEditorView(project: project)
                .environmentObject(appModel)
        }
        .alert(
            "Archive project?",
            isPresented: Binding(
                get: { projectToArchive != nil },
                set: { if !$0 { projectToArchive = nil } }
            ),
            presenting: projectToArchive
        ) { project in
            Button("Archive", role: .destructive) {
                appModel.setArchived(project, archived: true)
                projectToArchive = nil
            }
            Button("Cancel", role: .cancel) {
                projectToArchive = nil
            }
        } message: { project in
            Text("\(project.name) will be hidden from new timers. Its history will remain available.")
        }
    }
}

private struct ProjectRow: View {
    @EnvironmentObject private var appModel: AppModel
    let project: Project
    let editAction: () -> Void
    let archiveAction: () -> Void

    private var isActive: Bool {
        appModel.activeEntry?.project?.id == project.id
    }

    var body: some View {
        HStack(spacing: 14) {
            ProjectMark(project: project, size: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.headline)
                Text("\(DurationText.hours(Int(project.defaultWeeklyMinutes))) each week")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if isActive {
                Label(DurationText.clock(appModel.activeDuration), systemImage: "timer")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color(projectHex: project.colorHex))
            } else {
                Button {
                    appModel.startTimer(for: project)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Menu {
                Button("Edit", systemImage: "pencil", action: editAction)
                Button("Archive", systemImage: "archivebox", role: .destructive, action: archiveAction)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contextMenu {
            Button("Edit", action: editAction)
            Button("Archive", role: .destructive, action: archiveAction)
        }
    }
}
