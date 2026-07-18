import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingNewEntry = false
    @State private var editingEntry: TimeEntry?
    @State private var splittingEntry: TimeEntry?
    @State private var editingFocusSession: FocusSession?
    @State private var entryToDelete: TimeEntry?
    @State private var sessionToDelete: FocusSession?
    @State private var searchText = ""
    @State private var selectedTag = ""

    private var weekSessions: [FocusSession] {
        appModel.focusSessions(in: appModel.selectedWeekStart)
    }

    private var filteredSessions: [FocusSession] {
        weekSessions.filter { session in
            matchesSelectedTag(session) && matchesSearch(session)
        }
    }

    private var weekTagNames: [String] {
        var seen = Set<String>()
        return weekSessions
            .flatMap(\.sortedTags)
            .map(\.name)
            .filter { seen.insert(FocusMetadata.normalizedTag($0)).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            pageContent
        }
        .navigationTitle("Activity")
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Projects, notes, tags, or links"
        )
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingNewEntry = true
                } label: {
                    Label("Add time", systemImage: "plus")
                }
                .disabled(appModel.activeProjects.isEmpty)

                Menu {
                    Button("All tags") {
                        selectedTag = ""
                    }
                    if !weekTagNames.isEmpty {
                        Divider()
                        ForEach(weekTagNames, id: \.self) { tag in
                            Button {
                                selectedTag = tag
                            } label: {
                                if FocusMetadata.normalizedTag(selectedTag)
                                    == FocusMetadata.normalizedTag(tag) {
                                    Label("#\(tag)", systemImage: "checkmark")
                                } else {
                                    Text("#\(tag)")
                                }
                            }
                        }
                    }
                } label: {
                    Label(
                        selectedTag.isEmpty ? "Filter tags" : "#\(selectedTag)",
                        systemImage: "tag"
                    )
                }
                .disabled(weekTagNames.isEmpty)

                WeekNavigation()
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            TimeEntryEditorView(entry: nil)
                .environmentObject(appModel)
        }
        .sheet(item: $editingEntry) { entry in
            TimeEntryEditorView(entry: entry)
                .environmentObject(appModel)
        }
        .sheet(item: $splittingEntry) { entry in
            TimeEntrySplitView(entry: entry)
                .environmentObject(appModel)
        }
        .sheet(item: $editingFocusSession) { session in
            FocusMetadataEditorView(
                title: "Edit focus session",
                noteMarkdown: session.noteMarkdown,
                tagNames: session.sortedTags.map(\.name)
            ) { note, tags in
                appModel.updateFocusSession(
                    session,
                    noteMarkdown: note,
                    tagNames: tags
                )
            }
            .environmentObject(appModel)
        }
        .alert(
            "Delete time segment?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            presenting: entryToDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                appModel.deleteEntry(entry)
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: { entry in
            Text(deleteEntryMessage(for: entry))
        }
        .alert(
            "Delete focus session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            presenting: sessionToDelete
        ) { session in
            Button("Delete", role: .destructive) {
                appModel.deleteFocusSession(session)
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: { session in
            Text(deleteSessionMessage(for: session))
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            activityHeader
            selectedTagIndicator
            sessionList
        }
        .padding(26)
    }

    private var activityHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Activity")
                .font(.largeTitle.bold())
            Text("Review focus sessions, their notes, and the timer segments that make up your week.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var selectedTagIndicator: some View {
        if !selectedTag.isEmpty {
            HStack(spacing: 7) {
                Text("Filtered by")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TagPill(name: selectedTag) {
                    selectedTag = ""
                }
            }
        }
    }

    @ViewBuilder
    private var sessionList: some View {
        if weekSessions.isEmpty {
            ContentUnavailableView(
                "No activity this week",
                systemImage: "clock.arrow.circlepath",
                description: Text("Start a timer from the menu bar or add time manually.")
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if filteredSessions.isEmpty {
            ContentUnavailableView.search(text: searchDescription)
                .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            VStack(spacing: 0) {
                ForEach(filteredSessions) { session in
                    sessionRow(session)
                    if session.id != filteredSessions.last?.id {
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var searchDescription: String {
        if !searchText.isEmpty { return searchText }
        return selectedTag.isEmpty ? "activity" : "#\(selectedTag)"
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        FocusSessionRow(
            session: session,
            weekStart: appModel.selectedWeekStart,
            editMetadataAction: { editingFocusSession = session },
            editEntryAction: editEntry,
            splitEntryAction: splitEntry,
            deleteEntryAction: requestEntryDeletion,
            deleteSessionAction: { sessionToDelete = session }
        )
    }

    private func editEntry(_ entry: TimeEntry) {
        editingEntry = entry
    }

    private func splitEntry(_ entry: TimeEntry) {
        splittingEntry = entry
    }

    private func requestEntryDeletion(_ entry: TimeEntry) {
        entryToDelete = entry
    }

    private func matchesSelectedTag(_ session: FocusSession) -> Bool {
        guard !selectedTag.isEmpty else { return true }
        let selected = FocusMetadata.normalizedTag(selectedTag)
        return session.sortedTags.contains { $0.normalizedName == selected }
    }

    private func matchesSearch(_ session: FocusSession) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let normalizedQuery = query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let searchable = [
            session.project?.name ?? "",
            session.noteMarkdown,
            session.sortedTags.map(\.name).joined(separator: " "),
            FocusMetadata.safeLinks(in: session.noteMarkdown)
                .map(\.absoluteString)
                .joined(separator: " ")
        ]
        .joined(separator: " ")
        .folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return searchable.localizedStandardContains(normalizedQuery)
    }

    private func deleteEntryMessage(for entry: TimeEntry) -> String {
        let duration = DurationText.compact(entry.duration(at: appModel.now))
        let projectName = entry.project?.name ?? "this project"
        return "This removes the \(duration) segment from \(projectName) and updates your weekly totals. This action cannot be undone."
    }

    private func deleteSessionMessage(for session: FocusSession) -> String {
        let duration = DurationText.compact(
            appModel.duration(for: session, in: appModel.selectedWeekStart)
        )
        let segmentCount = session.sortedEntries.count
        return "This removes \(duration) across \(segmentCount) timer \(segmentCount == 1 ? "segment" : "segments"), including its note and tags. This action cannot be undone."
    }
}
