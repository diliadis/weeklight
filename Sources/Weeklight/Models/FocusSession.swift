import CoreData
import Foundation

@objc(WeeklightFocusSession)
final class FocusSession: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var noteMarkdown: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var project: Project?
    @NSManaged var entries: NSSet?
    @NSManaged var tags: NSSet?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        project: Project?,
        noteMarkdown: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(
            forEntityName: "FocusSession",
            in: context
        )!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.project = project
        self.noteMarkdown = noteMarkdown
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sortedEntries: [TimeEntry] {
        let values = entries as? Set<TimeEntry> ?? []
        return values.sorted { $0.startedAt < $1.startedAt }
    }

    var sortedTags: [FocusTag] {
        let values = tags as? Set<FocusTag> ?? []
        return values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var isRunning: Bool {
        sortedEntries.contains(where: \.isRunning)
    }

    var startedAt: Date? {
        sortedEntries.first?.startedAt
    }

    var endedAt: Date? {
        guard !isRunning else { return nil }
        return sortedEntries.compactMap(\.endedAt).max()
    }

    func duration(at date: Date = .now) -> TimeInterval {
        sortedEntries.reduce(0) { $0 + $1.duration(at: date) }
    }
}

extension FocusSession: Identifiable {}
