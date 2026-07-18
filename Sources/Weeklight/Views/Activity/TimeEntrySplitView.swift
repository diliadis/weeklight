import SwiftUI

struct TimeEntrySplitView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let entry: TimeEntry

    @State private var splitDate: Date
    @State private var secondProjectID: UUID?
    @State private var secondNote: String
    @State private var secondTagNames: [String]

    init(entry: TimeEntry) {
        self.entry = entry
        let end = entry.endedAt ?? entry.startedAt.addingTimeInterval(2 * 60)
        let midpoint = entry.startedAt.addingTimeInterval(
            end.timeIntervalSince(entry.startedAt) / 2
        )
        _splitDate = State(initialValue: midpoint)
        _secondProjectID = State(initialValue: entry.project?.id)
        _secondNote = State(
            initialValue: entry.focusSession?.noteMarkdown ?? entry.note
        )
        _secondTagNames = State(
            initialValue: entry.focusSession?.sortedTags.map(\.name) ?? []
        )
    }

    private var availableProjects: [Project] {
        var result = appModel.activeProjects
        if let originalProject = entry.project,
           !result.contains(where: { $0.id == originalProject.id }) {
            result.append(originalProject)
        }
        return result
    }

    private var secondProject: Project? {
        guard let secondProjectID else { return nil }
        return availableProjects.first { $0.id == secondProjectID }
    }

    private var end: Date {
        entry.endedAt ?? entry.startedAt.addingTimeInterval(2 * 60)
    }

    private var splitRange: ClosedRange<Date> {
        entry.startedAt.addingTimeInterval(60)...end.addingTimeInterval(-60)
    }

    private var firstDuration: TimeInterval {
        splitDate.timeIntervalSince(entry.startedAt)
    }

    private var secondDuration: TimeInterval {
        end.timeIntervalSince(splitDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Original session") {
                    LabeledContent("Project") {
                        HStack(spacing: 7) {
                            if let project = entry.project {
                                ProjectMark(project: project, size: 9)
                            }
                            Text(entry.project?.name ?? "Deleted project")
                        }
                    }
                    LabeledContent("Time", value: originalTimeRange)
                    LabeledContent(
                        "Duration",
                        value: DurationText.compact(entry.duration(at: appModel.now))
                    )
                }

                Section("Split") {
                    DatePicker("Split at", selection: $splitDate, in: splitRange)

                    LabeledContent("Earlier segment") {
                        Text(DurationText.compact(firstDuration))
                            .monospacedDigit()
                    }
                    LabeledContent("Later segment") {
                        Text(DurationText.compact(secondDuration))
                            .monospacedDigit()
                    }
                }

                Section {
                    Picker("Project", selection: projectSelection) {
                        ForEach(availableProjects) { project in
                            HStack {
                                ProjectMark(project: project)
                                Text(project.name)
                            }
                            .tag(project.id)
                        }
                    }
                    MarkdownNoteEditor(markdown: $secondNote, minimumHeight: 200)
                    TagEditor(
                        tags: $secondTagNames,
                        suggestions: appModel.suggestedTagNames
                    )
                } header: {
                    Text("Later segment")
                } footer: {
                    Text("The later segment becomes a new focus session. It starts with a copy of the current note and tags, which you can change here.")
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Spacer()
                Button("Split session") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    secondProject == nil
                        || secondNote.count > FocusMetadata.maximumNoteLength
                )
            }
            .padding(16)
        }
        .frame(width: 660, height: 760)
        .onAppear {
            if secondProjectID == nil {
                secondProjectID = availableProjects.first?.id
            }
        }
    }

    private var projectSelection: Binding<UUID> {
        Binding(
            get: { secondProjectID ?? availableProjects.first?.id ?? UUID() },
            set: { secondProjectID = $0 }
        )
    }

    private var originalTimeRange: String {
        let day = WeeklightFormatters.day.string(from: entry.startedAt)
        let start = WeeklightFormatters.time.string(from: entry.startedAt)
        let finish = WeeklightFormatters.time.string(from: end)
        return "\(day), \(start)–\(finish)"
    }

    private func save() {
        guard let secondProject else { return }
        if appModel.splitEntry(
            entry,
            at: splitDate,
            secondProject: secondProject,
            secondNote: secondNote,
            secondTagNames: secondTagNames
        ) {
            dismiss()
        }
    }
}
