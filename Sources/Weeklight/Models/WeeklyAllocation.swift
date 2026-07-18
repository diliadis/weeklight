import CoreData
import Foundation

@objc(WeeklightWeeklyAllocation)
final class WeeklyAllocation: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var weekStart: Date
    @NSManaged var plannedMinutes: Int32
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var project: Project?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        project: Project,
        weekStart: Date,
        plannedMinutes: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.init(context: context)
        self.id = id
        self.project = project
        self.weekStart = weekStart
        self.plannedMinutes = Int32(plannedMinutes)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension WeeklyAllocation: Identifiable {}
