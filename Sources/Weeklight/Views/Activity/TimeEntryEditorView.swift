import SwiftUI

struct TimeEntryEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry?

    @State private var selectedProjectID: UUID?
    @State private var start: Date
    @State private var end: Date
    @State private var note: String
    @State private var tagNames: [String]

    init(entry: TimeEntry?) {
        self.entry = entry
        let defaultEnd = entry?.endedAt ?? .now
        _selectedProjectID = State(initialValue: entry?.project?.id)
        _start = State(
            initialValue: entry?.startedAt ?? defaultEnd.addingTimeInterval(-60 * 60)
        )
        _end = State(initialValue: defaultEnd)
        _note = State(
            initialValue: entry?.focusSession?.noteMarkdown ?? entry?.note ?? ""
        )
        _tagNames = State(
            initialValue: entry?.focusSession?.sortedTags.map(\.name) ?? []
        )
    }

    private var availableProjects: [Project] {
        var result = appModel.activeProjects
        if let existing = entry?.project,
           !result.contains(where: { $0.id == existing.id }) {
            result.append(existing)
        }
        return result
    }

    private var selectedProject: Project? {
        let id = selectedProjectID ?? availableProjects.first?.id
        return availableProjects.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Session") {
                    Picker("Project", selection: projectSelection) {
                        ForEach(availableProjects) { project in
                            HStack {
                                ProjectMark(project: project)
                                Text(project.name)
                            }
                            .tag(project.id)
                        }
                    }

                    DatePicker("Start", selection: $start)
                    DatePicker("End", selection: $end)
                }

                Section {
                    MarkdownNoteEditor(markdown: $note, minimumHeight: 230)
                    TagEditor(tags: $tagNames, suggestions: appModel.suggestedTagNames)
                } header: {
                    Text("Focus details")
                } footer: {
                    if let session = entry?.focusSession,
                       session.sortedEntries.count > 1 {
                        Text("The project, note, and tags apply to all \(session.sortedEntries.count) segments in this focus session.")
                    } else {
                        Text("Markdown and web links are supported. GitHub commits, pull requests, and issues are recognized automatically.")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button(entry == nil ? "Add time" : "Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 660, height: 700)
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = availableProjects.first?.id
            }
        }
    }

    private var projectSelection: Binding<UUID> {
        Binding(
            get: { selectedProjectID ?? availableProjects.first?.id ?? UUID() },
            set: { selectedProjectID = $0 }
        )
    }

    private var canSave: Bool {
        selectedProject != nil
            && end > start
            && note.count <= FocusMetadata.maximumNoteLength
    }

    private func save() {
        guard let project = selectedProject else { return }
        let didSave: Bool
        if let entry {
            didSave = appModel.updateEntry(
                entry,
                project: project,
                start: start,
                end: end,
                note: note,
                tagNames: tagNames
            )
        } else {
            didSave = appModel.addManualEntry(
                project: project,
                start: start,
                end: end,
                note: note,
                tagNames: tagNames
            )
        }
        if didSave {
            dismiss()
        }
    }
}
