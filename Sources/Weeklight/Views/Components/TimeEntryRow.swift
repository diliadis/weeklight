import SwiftUI

struct TimeEntryRow: View {
    @EnvironmentObject private var appModel: AppModel
    let entry: TimeEntry
    var showsActions = true
    var showsNote = true
    var editAction: (() -> Void)?
    var splitAction: (() -> Void)?
    var deleteAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let project = entry.project {
                ProjectMark(project: project, size: 10)
            } else {
                Circle()
                    .fill(.secondary)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.project?.name ?? "Deleted project")
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(WeeklightFormatters.day.string(from: entry.startedAt))
                    Text("·")
                    Text(timeRange)
                    if showsNote, !entry.note.isEmpty {
                        Text("·")
                        Text(FocusMetadata.summary(from: entry.note, limit: 80))
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(DurationText.compact(entry.duration(at: appModel.now)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            if showsActions {
                Menu {
                    if let editAction {
                        Button("Edit", systemImage: "pencil", action: editAction)
                    }
                    if let splitAction {
                        Button("Split", systemImage: "scissors", action: splitAction)
                    }
                    if let deleteAction {
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive, action: deleteAction)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var timeRange: String {
        let start = WeeklightFormatters.time.string(from: entry.startedAt)
        guard let endedAt = entry.endedAt else {
            return start + "–now"
        }
        return start + "–" + WeeklightFormatters.time.string(from: endedAt)
    }
}
