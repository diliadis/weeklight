import SwiftUI

struct FocusSessionRow: View {
    @EnvironmentObject private var appModel: AppModel

    let session: FocusSession
    let weekStart: Date
    var showsActions = true
    var editMetadataAction: (() -> Void)?
    var editEntryAction: ((TimeEntry) -> Void)?
    var splitEntryAction: ((TimeEntry) -> Void)?
    var deleteEntryAction: ((TimeEntry) -> Void)?
    var deleteSessionAction: (() -> Void)?

    @State private var isExpanded = false

    private var visibleEntries: [TimeEntry] {
        let visibleIDs = Set(appModel.entries(in: weekStart).map(\.id))
        return session.sortedEntries.filter { visibleIDs.contains($0.id) }
    }

    private var noteSummary: String {
        FocusMetadata.summary(from: session.noteMarkdown, limit: 180)
    }

    private var links: [URL] {
        FocusMetadata.safeLinks(in: session.noteMarkdown)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if let project = session.project {
                        ProjectMark(project: project, size: 10)
                    } else {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 7) {
                            Text(session.project?.name ?? "Deleted project")
                                .lineLimit(1)
                            if session.isRunning {
                                Label("Running", systemImage: "record.circle.fill")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(sessionTimeSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DurationText.compact(appModel.duration(for: session, in: weekStart)))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if showsActions {
                        actionsMenu
                    }
                }

                if !noteSummary.isEmpty {
                    Text(noteSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.leading, 22)
                }

                if !session.sortedTags.isEmpty || !links.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(session.sortedTags) { tag in
                                TagPill(name: tag.name)
                            }

                            ForEach(Array(links.prefix(3)), id: \.absoluteString) { url in
                                Link(destination: url) {
                                    Label(
                                        linkTitle(for: url),
                                        systemImage: FocusMetadata.githubReference(for: url) == nil
                                            ? "link"
                                            : "chevron.left.forwardslash.chevron.right"
                                    )
                                    .lineLimit(1)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                        }
                        .padding(.leading, 22)
                    }
                }

                if visibleEntries.count > 1 {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label(
                            isExpanded ? "Hide segments" : "Show \(visibleEntries.count) segments",
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if isExpanded, visibleEntries.count > 1 {
                Divider().padding(.leading, 38)
                VStack(spacing: 0) {
                    ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                        TimeEntryRow(
                            entry: entry,
                            showsNote: false,
                            editAction: entry.isRunning ? nil : { editEntryAction?(entry) },
                            splitAction: canSplit(entry) ? { splitEntryAction?(entry) } : nil,
                            deleteAction: entry.isRunning ? nil : { deleteEntryAction?(entry) }
                        )
                        .padding(.leading, 20)
                        if index < visibleEntries.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background(.quaternary.opacity(0.25))
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            if let editMetadataAction {
                Button("Edit notes and tags", systemImage: "note.text", action: editMetadataAction)
            }

            if visibleEntries.count == 1, let entry = visibleEntries.first {
                if !entry.isRunning, let editEntryAction {
                    Button("Edit time", systemImage: "calendar.badge.clock") {
                        editEntryAction(entry)
                    }
                }
                if canSplit(entry), let splitEntryAction {
                    Button("Split", systemImage: "scissors") {
                        splitEntryAction(entry)
                    }
                }
            }

            if let deleteSessionAction, !session.isRunning {
                Divider()
                Button("Delete focus session", systemImage: "trash", role: .destructive) {
                    deleteSessionAction()
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sessionTimeSummary: String {
        guard let startedAt = session.startedAt else { return "No tracked segments" }
        let day = WeeklightFormatters.day.string(from: startedAt)
        let start = WeeklightFormatters.time.string(from: startedAt)
        let end: String
        if session.isRunning {
            end = "now"
        } else if let endedAt = session.endedAt {
            end = WeeklightFormatters.time.string(from: endedAt)
        } else {
            end = start
        }
        let segments = visibleEntries.count > 1 ? " · \(visibleEntries.count) segments" : ""
        return "\(day) · \(start)–\(end)\(segments)"
    }

    private func linkTitle(for url: URL) -> String {
        FocusMetadata.githubReference(for: url)?.compactTitle
            ?? url.host(percentEncoded: false)
            ?? url.absoluteString
    }

    private func canSplit(_ entry: TimeEntry) -> Bool {
        guard splitEntryAction != nil,
              !entry.isRunning,
              let endedAt = entry.endedAt else { return false }
        return endedAt.timeIntervalSince(entry.startedAt) >= 2 * 60
    }
}
