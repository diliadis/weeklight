import CoreData
import Foundation

enum PersistenceFactory {
    private enum SchemaVersion: String, CaseIterable {
        case v1 = "WeeklightSchemaV1"
        case v2 = "WeeklightSchemaV2"
        case v3 = "WeeklightSchemaV3"

        var includesCountdown: Bool { self != .v1 }
        var includesFocusSessions: Bool { self == .v3 }
    }

    private enum PersistenceError: LocalizedError {
        case unsupportedStore

        var errorDescription: String? {
            "The Weeklight database uses an unsupported schema version."
        }
    }

    static func makeContainer(
        inMemory: Bool = false,
        storeURL customStoreURL: URL? = nil
    ) throws -> NSPersistentContainer {
        let model = makeModel(version: .v3)
        let container = NSPersistentContainer(
            name: "Weeklight",
            managedObjectModel: model
        )
        let coordinator = container.persistentStoreCoordinator

        let storeType: NSPersistentStore.StoreType
        let storeURL: URL
        if inMemory {
            storeType = .inMemory
            storeURL = URL(fileURLWithPath: "/dev/null")
        } else {
            storeType = .sqlite
            storeURL = try customStoreURL ?? persistentStoreURL()
            try migrateStoreIfNeeded(at: storeURL, destinationModel: model)
        }

        _ = try coordinator.addPersistentStore(
            type: storeType,
            configuration: nil,
            at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
        )

        container.viewContext.mergePolicy = NSMergePolicy(
            merge: .mergeByPropertyObjectTrumpMergePolicyType
        )
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
        try backfillFocusSessions(in: container.viewContext)
        return container
    }

#if DEBUG
    static func makeLegacyV1Container(at storeURL: URL) throws -> NSPersistentContainer {
        try makeLegacyContainer(version: .v1, at: storeURL)
    }

    static func makeLegacyV2Container(at storeURL: URL) throws -> NSPersistentContainer {
        try makeLegacyContainer(version: .v2, at: storeURL)
    }

    private static func makeLegacyContainer(
        version: SchemaVersion,
        at storeURL: URL
    ) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: "WeeklightLegacy",
            managedObjectModel: makeModel(version: version)
        )
        _ = try container.persistentStoreCoordinator.addPersistentStore(
            type: .sqlite,
            configuration: nil,
            at: storeURL,
            options: nil
        )
        return container
    }
#endif

    private static func persistentStoreURL() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("Weeklight", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("Weeklight.sqlite")
    }

    private static func makeModel(version: SchemaVersion) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = [version.rawValue]

        let project = NSEntityDescription()
        project.name = "Project"
        project.managedObjectClassName = NSStringFromClass(Project.self)
        project.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("colorHex", .stringAttributeType),
            attribute("defaultWeeklyMinutes", .integer32AttributeType, defaultValue: 0),
            attribute("isArchived", .booleanAttributeType, defaultValue: false),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]
        project.uniquenessConstraints = [["id"]]

        let allocation = NSEntityDescription()
        allocation.name = "WeeklyAllocation"
        allocation.managedObjectClassName = NSStringFromClass(WeeklyAllocation.self)
        let allocationProject = toOneRelationship(
            "project",
            destination: project,
            deleteRule: .nullifyDeleteRule
        )
        allocation.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("weekStart", .dateAttributeType),
            attribute("plannedMinutes", .integer32AttributeType, defaultValue: 0),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType),
            allocationProject
        ]
        allocation.uniquenessConstraints = [["id"]]

        let entry = NSEntityDescription()
        entry.name = "TimeEntry"
        entry.managedObjectClassName = NSStringFromClass(TimeEntry.self)
        let entryProject = toOneRelationship(
            "project",
            destination: project,
            deleteRule: .nullifyDeleteRule
        )
        var entryProperties: [NSPropertyDescription] = [
            attribute("id", .UUIDAttributeType),
            attribute("startedAt", .dateAttributeType),
            attribute("endedAt", .dateAttributeType, isOptional: true),
            attribute("note", .stringAttributeType, defaultValue: ""),
            attribute(
                "sourceRawValue",
                .stringAttributeType,
                defaultValue: TimeEntrySource.timer.rawValue
            ),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType),
            entryProject
        ]
        if version.includesCountdown {
            entryProperties.insert(
                attribute(
                    "countdownDurationSeconds",
                    .doubleAttributeType,
                    isOptional: true
                ),
                at: entryProperties.count - 1
            )
        }

        var focusSession: NSEntityDescription?
        var focusTag: NSEntityDescription?
        if version.includesFocusSessions {
            let session = NSEntityDescription()
            session.name = "FocusSession"
            session.managedObjectClassName = NSStringFromClass(FocusSession.self)

            let tag = NSEntityDescription()
            tag.name = "FocusTag"
            tag.managedObjectClassName = NSStringFromClass(FocusTag.self)

            let sessionProject = toOneRelationship(
                "project",
                destination: project,
                deleteRule: .nullifyDeleteRule
            )
            let entrySession = toOneRelationship(
                "focusSession",
                destination: session,
                deleteRule: .nullifyDeleteRule
            )
            let sessionEntries = toManyRelationship(
                "entries",
                destination: entry,
                deleteRule: .cascadeDeleteRule
            )
            entrySession.inverseRelationship = sessionEntries
            sessionEntries.inverseRelationship = entrySession

            let sessionTags = toManyRelationship(
                "tags",
                destination: tag,
                deleteRule: .nullifyDeleteRule
            )
            let tagSessions = toManyRelationship(
                "sessions",
                destination: session,
                deleteRule: .nullifyDeleteRule
            )
            sessionTags.inverseRelationship = tagSessions
            tagSessions.inverseRelationship = sessionTags

            session.properties = [
                attribute("id", .UUIDAttributeType),
                attribute("noteMarkdown", .stringAttributeType, defaultValue: ""),
                attribute("createdAt", .dateAttributeType),
                attribute("updatedAt", .dateAttributeType),
                sessionProject,
                sessionEntries,
                sessionTags
            ]
            session.uniquenessConstraints = [["id"]]

            tag.properties = [
                attribute("id", .UUIDAttributeType),
                attribute("name", .stringAttributeType),
                attribute("normalizedName", .stringAttributeType),
                attribute("createdAt", .dateAttributeType),
                attribute("updatedAt", .dateAttributeType),
                tagSessions
            ]
            tag.uniquenessConstraints = [["id"], ["normalizedName"]]

            entryProperties.append(entrySession)
            focusSession = session
            focusTag = tag
        }

        entry.properties = entryProperties
        entry.uniquenessConstraints = [["id"]]

        model.entities = [project, allocation, entry]
            + [focusSession, focusTag].compactMap { $0 }
        return model
    }

    private static func migrateStoreIfNeeded(
        at storeURL: URL,
        destinationModel: NSManagedObjectModel
    ) throws {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            type: .sqlite,
            at: storeURL,
            options: nil
        )
        guard !destinationModel.isConfiguration(
            withName: nil,
            compatibleWithStoreMetadata: metadata
        ) else { return }

        let sourceModel = [SchemaVersion.v2, .v1]
            .map(makeModel(version:))
            .first {
                $0.isConfiguration(
                    withName: nil,
                    compatibleWithStoreMetadata: metadata
                )
            }
        guard let sourceModel else {
            throw PersistenceError.unsupportedStore
        }

        let mapping = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        )
        let manager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )
        let migratedURL = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("Weeklight-migrated-\(UUID().uuidString).sqlite")

        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: migratedURL.path + suffix)
                )
            }
        }

        try manager.migrateStore(
            from: storeURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mapping,
            toDestinationURL: migratedURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: destinationModel
        )
        try coordinator.replacePersistentStore(
            at: storeURL,
            destinationOptions: nil,
            withPersistentStoreFrom: migratedURL,
            sourceOptions: nil,
            ofType: NSSQLiteStoreType
        )
    }

    private static func backfillFocusSessions(
        in context: NSManagedObjectContext
    ) throws {
        let request = NSFetchRequest<TimeEntry>(entityName: "TimeEntry")
        request.predicate = NSPredicate(format: "focusSession == nil")
        let entries = try context.fetch(request)
        guard !entries.isEmpty else { return }

        for entry in entries {
            let session = FocusSession(
                context: context,
                project: entry.project,
                noteMarkdown: entry.note,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
            entry.focusSession = session
        }
        try context.save()
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        isOptional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func toOneRelationship(
        _ name: String,
        destination: NSEntityDescription,
        deleteRule: NSDeleteRule
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 1
        relationship.isOptional = true
        relationship.deleteRule = deleteRule
        return relationship
    }

    private static func toManyRelationship(
        _ name: String,
        destination: NSEntityDescription,
        deleteRule: NSDeleteRule
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = 0
        relationship.isOptional = true
        relationship.isOrdered = false
        relationship.deleteRule = deleteRule
        return relationship
    }
}
