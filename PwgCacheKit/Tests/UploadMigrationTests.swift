//
//  UploadMigrationTests.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 23 August 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import XCTest
@testable import PwgCacheKit

/**
 Guards the migration chain against duplicating pending upload requests.

 An `NSEntityMigrationPolicy` that builds its own destination instance must not
 also call `super.createDestinationInstances(forSource:in:manager:)`: the
 superclass creates and associates an instance of its own from the entity
 mapping, so every source row lands in the destination store twice. Nothing
 fails during the migration — the duplicate is a valid `Upload` — and the queue
 then sends every file waiting at upgrade time to the server twice.

 That is what `UploadToUploadMigrationPolicy_0N_to_0O` did, so an upgrade from
 v4.2.4 (model `0N`) to v4.4 uploaded each pending request twice; that step had
 no conversion to make and now runs `UploadToUploadMigrationPolicy_Copy`. The
 mistake is easy to reintroduce because the `…MigrationPolicy_Copy` classes
 legitimately call `super` — they create no instance of their own.
 */
final class UploadMigrationTests: XCTestCase {

    /// Steps whose mapping model wires a custom `Upload` migration policy.
    private static let uploadSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version0H, .version0J),   // UploadToUploadMigrationPolicy_0H_to_0J
        (.version0J, .version0L),   // UploadToUploadMigrationPolicy_0J_to_0K
        (.version0N, .version0O),   // UploadToUploadMigrationPolicy_Copy
        (.version0O, .version0P),   // UploadToUploadMigrationPolicy_Copy
    ]

    private let uploadCount = 3

    // MARK: - Helpers

    /**
     Creates a store of the given model version holding `uploads` upload
     requests.

     Required attributes are filled generically so that the fixture follows the
     `Upload` entity of any model version: an attribute with a default value
     keeps it, one without gets a placeholder of the right type.
     */
    private func makeStore(version: DataMigrationVersion, uploads: Int,
                          extraValues: [String: Any] = [:]) throws -> URL {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: version)
        let entity = try XCTUnwrap(model.entitiesByName["Upload"])
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        try context.performAndWait {
            for index in 0..<uploads {
                let upload = NSManagedObject(entity: entity, insertInto: context)
                for (name, attribute) in entity.attributesByName
                where !attribute.isOptional && attribute.defaultValue == nil {
                    upload.setValue(placeholder(for: attribute, index: index), forKey: name)
                }
                upload.setValue("asset-\(index)/L0/001", forKey: "localIdentifier")
                upload.setValue(fileName(index), forKey: "fileName")
                upload.setValue(pwgUploadState.waiting.rawValue, forKey: "requestState")
                for (name, value) in extraValues {
                    upload.setValue(value, forKey: name)
                }
            }
            try context.save()
        }

        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        return url
    }

    /// The last request of the fixture is a video, the others are photos.
    private func fileName(_ index: Int) -> String {
        index == uploadCount - 1 ? "MVI_000\(index).MP4" : "IMG_000\(index).JPG"
    }

    private func placeholder(for attribute: NSAttributeDescription, index: Int) -> Any? {
        switch attribute.attributeType {
        case .stringAttributeType:
            return "\(attribute.name)-\(index)"
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
            return 0
        case .doubleAttributeType, .floatAttributeType, .decimalAttributeType:
            return 0.0
        case .booleanAttributeType:
            return false
        case .dateAttributeType:
            return Date(timeIntervalSinceReferenceDate: 0)
        default:
            return nil
        }
    }

    /// The `localIdentifier` of every upload request held by a store, duplicates included.
    private func uploadedAssets(at url: URL, version: DataMigrationVersion) throws -> [String] {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: version)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Upload")
            return try context.fetch(request)
                .compactMap { $0.value(forKey: "localIdentifier") as? String }
                .sorted()
        }
    }

    private func expectedAssets(_ count: Int) -> [String] {
        (0..<count).map { "asset-\($0)/L0/001" }.sorted()
    }

    private func migrate(_ sourceURL: URL,
                         from source: DataMigrationVersion,
                         to destination: DataMigrationVersion) throws -> URL {
        let step = DataMigrationStep(sourceVersion: source, destinationVersion: destination)
        let manager = NSMigrationManager(sourceModel: step.sourceModel,
                                         destinationModel: step.destinationModel)
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).sqlite")
        try manager.migrateStore(from: sourceURL, type: .sqlite, options: nil,
                                 mapping: step.mappingModel,
                                 to: destinationURL, type: .sqlite, options: nil)
        return destinationURL
    }

    // MARK: - Tests

    /// No step carrying an Upload policy adds or drops upload requests.
    func testUploadRequestsSurviveEachStepUnchanged() throws {
        for (source, destination) in Self.uploadSteps {
            let sourceURL = try makeStore(version: source, uploads: uploadCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)
            XCTAssertEqual(try uploadedAssets(at: destinationURL, version: destination),
                           expectedAssets(uploadCount),
                           """
                           \(source.rawValue) ► \(destination.rawValue) changed the \
                           number of upload requests. A policy creating its own \
                           destination instance must not call \
                           super.createDestinationInstances(forSource:in:manager:).
                           """)
            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     `0H → 0J` converts the filename prefix settings, and the converted value
     has to land on the migrated request — which is a different object from the
     one the policy would have built itself.
     */
    func testFileNamePrefixIsConvertedBy0HTo0J() throws {
        let prefix = "Pwg-"
        let sourceURL = try makeStore(version: .version0H, uploads: uploadCount,
                                      extraValues: ["prefixFileNameBeforeUpload": true,
                                                    "defaultPrefix": prefix])
        let destinationURL = try migrate(sourceURL, from: .version0H, to: .version0J)

        let expected = "\(RenameAction.ActionType.addText.rawValue):\(try XCTUnwrap(prefix.base64Encoded))"
        let model = NSManagedObjectModel.managedObjectModel(forVersion: .version0J)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: destinationURL)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let uploads = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Upload"))
            XCTAssertEqual(uploads.count, uploadCount)
            for upload in uploads {
                XCTAssertEqual(upload.value(forKey: "fileNamePrefixEncodedActions") as? String, expected)
            }
        }

        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
        NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
    }

    /**
     `0J → 0L` derives 'fileType' from the old file name, and the derived value
     has to land on the migrated request.
     */
    func testFileTypeIsDerivedBy0JTo0L() throws {
        let sourceURL = try makeStore(version: .version0J, uploads: uploadCount)
        let destinationURL = try migrate(sourceURL, from: .version0J, to: .version0L)

        let model = NSManagedObjectModel.managedObjectModel(forVersion: .version0L)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: destinationURL)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let uploads = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "Upload"))
            XCTAssertEqual(uploads.count, uploadCount)
            for upload in uploads {
                let name = try XCTUnwrap(upload.value(forKey: "fileName") as? String)
                let expected: pwgImageFileType = name.hasSuffix(".MP4") ? .video : .image
                XCTAssertEqual(upload.value(forKey: "fileType") as? Int16, expected.rawValue,
                               "wrong file type migrated for \(name)")
            }
        }

        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
        NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
    }

    /// The two steps an upgrader from v4.2.4 to v4.4 runs, back to back.
    func testUploadRequestsSurviveTheUpgradeFrom0N() throws {
        let sourceURL = try makeStore(version: .version0N, uploads: uploadCount)
        let intermediateURL = try migrate(sourceURL, from: .version0N, to: .version0O)
        let destinationURL = try migrate(intermediateURL, from: .version0O, to: .version0P)
        XCTAssertEqual(try uploadedAssets(at: destinationURL, version: .version0P),
                       expectedAssets(uploadCount))
        for url in [sourceURL, intermediateURL, destinationURL] {
            NSPersistentStoreCoordinator.destroyStore(at: url)
        }
    }
}
