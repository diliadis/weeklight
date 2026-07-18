import CoreData
import Foundation

@objc(WeeklightProject)
final class Project: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var colorHex: String
    @NSManaged var defaultWeeklyMinutes: Int32
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        defaultWeeklyMinutes: Int,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.defaultWeeklyMinutes = Int32(defaultWeeklyMinutes)
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Project: Identifiable {}
