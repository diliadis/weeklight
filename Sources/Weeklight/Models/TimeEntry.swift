import CoreData
import Foundation

enum TimeEntrySource: String, Codable, CaseIterable, Sendable {
    case timer
    case manual
}

@objc(WeeklightTimeEntry)
final class TimeEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var startedAt: Date
    @NSManaged var endedAt: Date?
    @NSManaged var note: String
    @NSManaged var sourceRawValue: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var countdownDurationSeconds: NSNumber?
    @NSManaged var project: Project?
    @NSManaged var focusSession: FocusSession?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        project: Project,
        focusSession: FocusSession? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        note: String = "",
        source: TimeEntrySource = .timer,
        countdownDuration: TimeInterval? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.init(context: context)
        self.id = id
        self.project = project
        self.focusSession = focusSession
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.sourceRawValue = source.rawValue
        self.countdownDuration = countdownDuration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var source: TimeEntrySource {
        get { TimeEntrySource(rawValue: sourceRawValue) ?? .timer }
        set { sourceRawValue = newValue.rawValue }
    }

    var isRunning: Bool {
        endedAt == nil
    }

    var countdownDuration: TimeInterval? {
        get { countdownDurationSeconds?.doubleValue }
        set { countdownDurationSeconds = newValue.map(NSNumber.init(value:)) }
    }

    var isCountdown: Bool {
        countdownDuration != nil
    }

    var scheduledCountdownEnd: Date? {
        guard let countdownDuration else { return nil }
        return startedAt.addingTimeInterval(countdownDuration)
    }

    func duration(at date: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? date).timeIntervalSince(startedAt))
    }

    func remainingCountdown(at date: Date = .now) -> TimeInterval? {
        guard let countdownDuration else { return nil }
        return max(0, countdownDuration - duration(at: date))
    }
}

extension TimeEntry: Identifiable {}
