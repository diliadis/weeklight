import CoreData
import Foundation

@objc(WeeklightFocusTag)
final class FocusTag: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var normalizedName: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var sessions: NSSet?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        normalizedName: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        let entity = NSEntityDescription.entity(
            forEntityName: "FocusTag",
            in: context
        )!
        self.init(entity: entity, insertInto: context)
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension FocusTag: Identifiable {}
