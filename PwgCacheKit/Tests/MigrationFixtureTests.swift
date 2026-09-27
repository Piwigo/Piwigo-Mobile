//
//  MigrationFixtureTests.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 23 August 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import XCTest
@testable import PwgCacheKit

/**
 Runs the migration steps against fixture stores, checking what the policies
 write rather than what the mapping models declare.

 `MigrationChainTests` reads the mapping models without migrating anything,
 which settles what can be settled statically. The two failures below cannot be,
 and both shipped.

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

 A value expression whose result does not fit its destination attribute throws
 in the middle of the migration, on the user's store. `Image.downloadUrl ← ""`
 in `0F → 0H` put an empty string in a transformable `NSURL` attribute, so every
 upgrade from a v3.2 store aborted on the first image and never left the
 migration screen, from v4.3 through v4.4. An expression running a value
 transformer has no type a static audit can read; migrating a store exposes it.
 */
final class MigrationFixtureTests: XCTestCase {

    /// Steps whose mapping model wires a custom `Upload` migration policy.
    private static let uploadSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version0H, .version0J),   // UploadToUploadMigrationPolicy_0H_to_0J
        (.version0J, .version0L),   // UploadToUploadMigrationPolicy_0J_to_0K
        (.version0N, .version0O),   // UploadToUploadMigrationPolicy_Copy
        (.version0O, .version0P),   // UploadToUploadMigrationPolicy_Copy
    ]

    /// Steps whose mapping model wires an `Image` migration policy.
    /// `0F → 0H` and `0G → 0H` fill `title` and `comment`, which become required in `0G`,
    /// and create `downloadUrl`; the rest carry the shared copy policy or convert an
    /// attribute of their own.
    private static let imageSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version0B, .version0C),   // ImageToImageMigrationPolicy_Copy
        (.version0F, .version0H),   // ImageToImageMigrationPolicy_0F_to_0H
        (.version0G, .version0H),   // ImageToImageMigrationPolicy_0G_to_0H
        (.version0H, .version0J),   // ImageToImageMigrationPolicy_Copy
        (.version0I, .version0J),   // ImageToImageMigrationPolicy_Copy
        (.version0J, .version0L),   // ImageToImageMigrationPolicy_0J_to_0L
        (.version0K, .version0L),   // ImageToImageMigrationPolicy_0K_to_0L
        (.version0L, .version0N),   // ImageToImageMigrationPolicy_0L_to_0N
        (.version0M, .version0N),   // ImageToImageMigrationPolicy_Copy
        (.version0N, .version0O),   // ImageToImageMigrationPolicy_Copy
        (.version0O, .version0P),   // ImageToImageMigrationPolicy_Copy
    ]

    /// Steps whose mapping model wires an `Album` migration policy.
    /// `0F → 0H` fills `comment`, which becomes required in `0H`; the steps reaching `0L`
    /// derive `commentStr` and `commentHTML` from it, and those reaching `0N` add
    /// `commentRaw`. The rest carry the shared copy policy.
    private static let albumSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version0B, .version0C),   // AlbumToAlbumMigrationPolicy_0B_to_0C
        (.version0F, .version0H),   // AlbumToAlbumMigrationPolicy_0F_to_0H
        (.version0G, .version0H),   // AlbumToAlbumMigrationPolicy_Copy
        (.version0H, .version0J),   // AlbumToAlbumMigrationPolicy_Copy
        (.version0I, .version0J),   // AlbumToAlbumMigrationPolicy_Copy
        (.version0J, .version0L),   // AlbumToAlbumMigrationPolicy_0K_to_0L
        (.version0K, .version0L),   // AlbumToAlbumMigrationPolicy_0K_to_0L
        (.version0L, .version0N),   // AlbumToAlbumMigrationPolicy_0L_to_0N
        (.version0M, .version0N),   // AlbumToAlbumMigrationPolicy_Copy
        (.version0N, .version0O),   // AlbumToAlbumMigrationPolicy_Copy
        (.version0O, .version0P),   // AlbumToAlbumMigrationPolicy_Copy
    ]

    /// Steps whose mapping model wires a `Tag` migration policy.
    /// Every one of them copies the tag unchanged except `0O → 0P`, which renames
    /// `tagId` to `pwgID` and `tagName` to `name` — a rename the mapping model performs
    /// on its own, since that step still runs the shared copy policy.
    private static let tagSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version09, .version0C),   // TagToTagMigrationPolicy_09_to_0C
        (.version0B, .version0C),   // TagToTagMigrationPolicy_Copy
        (.version0F, .version0H),   // TagToTagMigrationPolicy_Copy
        (.version0G, .version0H),   // TagToTagMigrationPolicy_Copy
        (.version0H, .version0J),   // TagToTagMigrationPolicy_Copy
        (.version0I, .version0J),   // TagToTagMigrationPolicy_Copy
        (.version0J, .version0L),   // TagToTagMigrationPolicy_Copy
        (.version0K, .version0L),   // TagToTagMigrationPolicy_Copy
        (.version0L, .version0N),   // TagToTagMigrationPolicy_Copy
        (.version0M, .version0N),   // TagToTagMigrationPolicy_Copy
        (.version0N, .version0O),   // TagToTagMigrationPolicy_Copy
        (.version0O, .version0P),   // TagToTagMigrationPolicy_Copy
    ]

    /// Steps whose mapping model wires a `Sizes` migration policy.
    ///
    /// `0B → 0C` is missing on purpose: it runs `ImageToSizesMigrationPolicy_0B_to_0C`,
    /// which builds the Sizes out of an Image rather than out of a Sizes, so it needs an
    /// Image fixture and belongs with the Image steps.
    private static let sizesSteps: [(source: DataMigrationVersion, destination: DataMigrationVersion)] = [
        (.version0F, .version0H),   // SizesToSizesMigrationPolicy_Copy
        (.version0G, .version0H),   // SizesToSizesMigrationPolicy_Copy
        (.version0H, .version0J),   // SizesToSizesMigrationPolicy_Copy
        (.version0I, .version0J),   // SizesToSizesMigrationPolicy_Copy
        (.version0J, .version0L),   // SizesToSizesMigrationPolicy_Copy
        (.version0K, .version0L),   // SizesToSizesMigrationPolicy_Copy
        (.version0L, .version0N),   // SizesToSizesMigrationPolicy_0M_to_0N
        (.version0M, .version0N),   // SizesToSizesMigrationPolicy_0M_to_0N
        (.version0N, .version0O),   // SizesToSizesMigrationPolicy_Copy
        (.version0O, .version0P),   // SizesToSizesMigrationPolicy_Copy
    ]

    /// The size attributes every model from `0C` on declares.
    private static let sizeNames = ["square", "thumb", "xxsmall", "xsmall", "small",
                                    "medium", "large", "xlarge", "xxlarge"]

    private let uploadCount = 3
    private let imageCount = 3
    private let albumCount = 3
    private let tagCount = 3
    private let sizesCount = 3

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
        try makeStore(version: version, entityName: "Upload", rows: uploads) { upload, index in
            upload.setValue("asset-\(index)/L0/001", forKey: "localIdentifier")
            upload.setValue(fileName(index), forKey: "fileName")
            upload.setValue(pwgUploadState.waiting.rawValue, forKey: "requestState")
            for (name, value) in extraValues {
                upload.setValue(value, forKey: name)
            }
        }
    }

    /**
     Creates a store of the given model version holding `rows` instances of an entity.

     Required attributes are filled generically so that the fixture follows the entity
     of any model version: an attribute with a default value keeps it, one without gets
     a placeholder of the right type. `configure` then sets what the test cares about.
     Optional attributes are deliberately left nil — that is the state a migration
     policy filling a newly required attribute has to cope with.
     */
    private func makeStore(version: DataMigrationVersion, entityName: String, rows: Int,
                           configure: (NSManagedObject, Int) -> Void) throws -> URL {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: version)
        let entity = try XCTUnwrap(model.entitiesByName[entityName])
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(UUID().uuidString).sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        try context.performAndWait {
            for index in 0..<rows {
                let object = NSManagedObject(entity: entity, insertInto: context)
                for (name, attribute) in entity.attributesByName
                where !attribute.isOptional && attribute.defaultValue == nil {
                    object.setValue(placeholder(for: attribute, index: index), forKey: name)
                }
                configure(object, index)
            }
            try context.save()
        }

        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        return url
    }

    /// A store of `images` images of the given model version, titles and comments left nil.
    private func makeImageStore(version: DataMigrationVersion, images: Int) throws -> URL {
        try makeStore(version: version, entityName: "Image", rows: images) { image, index in
            image.setValue("image-\(index)", forKey: "uuid")
            image.setValue(Int64(index), forKey: "pwgID")
            image.setValue(fileName(index), forKey: "fileName")
        }
    }

    /// A store of `albums` albums of the given model version, comments left to the fixture.
    private func makeAlbumStore(version: DataMigrationVersion, albums: Int) throws -> URL {
        try makeStore(version: version, entityName: "Album", rows: albums) { album, index in
            album.setValue("album-\(index)", forKey: "uuid")
            album.setValue(Int32(index), forKey: "pwgID")
            album.setValue("Album \(index)", forKey: "name")
        }
    }

    /**
     A store of `tags` tags of the given model version.

     `0P` renames `tagId` to `pwgID` and `tagName` to `name`, so the fixture asks the
     entity which pair it holds rather than assuming one.
     */
    private func makeTagStore(version: DataMigrationVersion, tags: Int) throws -> URL {
        try makeStore(version: version, entityName: "Tag", rows: tags) { tag, index in
            let attributes = tag.entity.attributesByName
            tag.setValue(Int32(index + 100), forKey: attributes["pwgID"] != nil ? "pwgID" : "tagId")
            tag.setValue("tag-\(index)", forKey: attributes["name"] != nil ? "name" : "tagName")
        }
    }

    /// The name of every tag held by a store, whichever attribute carries it.
    private func cachedTagNames(at url: URL, version: DataMigrationVersion) throws -> [String] {
        try withRows(at: url, version: version, entityName: "Tag") { tags in
            tags.compactMap { tag in
                let key = tag.entity.attributesByName["name"] != nil ? "name" : "tagName"
                return tag.value(forKey: key) as? String
            }.sorted()
        }
    }

    private func expectedTagNames(_ count: Int) -> [String] {
        (0..<count).map { "tag-\($0)" }.sorted()
    }

    /**
     A store of `sizes` Sizes of the given model version, every size filled with a
     resolution of its own.

     The paths are left nil on purpose: `ResolutionValueTransformer` resolves a relative
     path against `ServerVars.shared.service`, which reads the app group `UserDefaults`
     and crashes outside the app. A resolution without a URL never reaches that branch.
     */
    private func makeSizesStore(version: DataMigrationVersion, sizes: Int) throws -> URL {
        try makeStore(version: version, entityName: "Sizes", rows: sizes) { size, index in
            for (rank, name) in Self.sizeNames.enumerated() {
                size.setValue(Resolution(imageWidth: Self.width(row: index, rank: rank),
                                         imageHeight: Self.height(row: index, rank: rank),
                                         imageURL: nil),
                              forKey: name)
            }
        }
    }

    /// Distinct pixel counts, so that a size landing in the wrong attribute is visible.
    private static func width(row: Int, rank: Int) -> Int { 1_000 + row * 100 + rank }
    private static func height(row: Int, rank: Int) -> Int { 5_000 + row * 100 + rank }

    /// The width of the `square` of every Sizes held by a store, which identifies its row.
    private func cachedSquareWidths(at url: URL, version: DataMigrationVersion) throws -> [Int] {
        try withRows(at: url, version: version, entityName: "Sizes") { rows in
            rows.compactMap { ($0.value(forKey: "square") as? Resolution)?.width }.sorted()
        }
    }

    private func expectedSquareWidths(_ count: Int) -> [Int] {
        (0..<count).map { Self.width(row: $0, rank: 0) }.sorted()
    }

    /// The `uuid` of every instance of an entity held by a store, duplicates included.
    private func cachedUUIDs(at url: URL, version: DataMigrationVersion,
                             entityName: String) throws -> [String] {
        try withRows(at: url, version: version, entityName: entityName) { rows in
            rows.compactMap { $0.value(forKey: "uuid") as? String }.sorted()
        }
    }

    private func expectedUUIDs(_ prefix: String, _ count: Int) -> [String] {
        (0..<count).map { "\(prefix)-\($0)" }.sorted()
    }

    /// Opens a store and hands the instances of an entity to `body`.
    private func withRows<T>(at url: URL, version: DataMigrationVersion, entityName: String,
                             _ body: ([NSManagedObject]) throws -> T) throws -> T {
        let model = NSManagedObjectModel.managedObjectModel(forVersion: version)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(type: .sqlite, at: url)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            try body(try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entityName)))
        }
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
        case .transformableAttributeType:
            /// A required transformable attribute only accepts an instance of the class it
            /// declares — `Image.title` and `Image.comment` hold an `NSAttributedString` from
            /// `0G` on — and Core Data refuses to save nil in its place. Any other value class
            /// returns nil, so a fixture needing one fails loudly rather than silently.
            switch attribute.attributeValueClassName {
            case "NSAttributedString":
                return NSAttributedString(string: "\(attribute.name)-\(index)")
            case "NSURL":
                return URL(fileURLWithPath: "/\(attribute.name)-\(index)")
            default:
                return nil
            }
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

    // MARK: - Image

    /// No step carrying an Image policy adds or drops images.
    func testImagesSurviveEachStepUnchanged() throws {
        for (source, destination) in Self.imageSteps {
            let sourceURL = try makeImageStore(version: source, images: imageCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)
            XCTAssertEqual(try cachedUUIDs(at: destinationURL, version: destination, entityName: "Image"),
                           expectedUUIDs("image", imageCount),
                           """
                           \(source.rawValue) ► \(destination.rawValue) changed the \
                           number of images. A policy creating its own destination \
                           instance must not call \
                           super.createDestinationInstances(forSource:in:manager:).
                           """)
            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     `title` and `comment` are optional up to `0F` and required from `0G` on, so the
     policies reaching `0H` have to put an empty `NSAttributedString` where the source
     held nil. A migration leaving them nil fails to save the destination store.
     */
    func testTitleAndCommentAreFilledOnTheStepsReaching0H() throws {
        for source in [DataMigrationVersion.version0F, .version0G] {
            let sourceURL = try makeImageStore(version: source, images: imageCount)
            let destinationURL = try migrate(sourceURL, from: source, to: .version0H)

            try withRows(at: destinationURL, version: .version0H, entityName: "Image") { images in
                XCTAssertEqual(images.count, imageCount)
                for image in images {
                    XCTAssertNotNil(image.value(forKey: "title") as? NSAttributedString,
                                    "\(source.rawValue) ► 0H left title nil, which 0H forbids")
                    XCTAssertNotNil(image.value(forKey: "comment") as? NSAttributedString,
                                    "\(source.rawValue) ► 0H left comment nil, which 0H forbids")
                }
            }

            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     `downloadUrl` appears in `0H` and is filled by the server, not by the migration,
     so it must arrive nil.

     The `0F → 0H` mapping model used to assign it the constant `""`. The attribute is
     transformable holding an `NSURL`, so Core Data threw
     `NSInvalidArgumentException: Unacceptable type of value for attribute` on the first
     image and aborted the migration — every upgrade from a v3.2 store crashed on the
     migration screen from v4.3 through v4.4. This test migrates a real store, so it
     fails on the exception itself rather than on the assertion below.
     */
    func testDownloadUrlIsNilOnTheStepsReaching0H() throws {
        for source in [DataMigrationVersion.version0F, .version0G] {
            let sourceURL = try makeImageStore(version: source, images: imageCount)
            let destinationURL = try migrate(sourceURL, from: source, to: .version0H)

            try withRows(at: destinationURL, version: .version0H, entityName: "Image") { images in
                XCTAssertEqual(images.count, imageCount)
                for image in images {
                    XCTAssertNil(image.value(forKey: "downloadUrl"),
                                 "\(source.rawValue) ► 0H invented a downloadUrl")
                }
            }

            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /// The whole chain a v3.2 upgrader runs, `0F` to the current model, step after step.
    func testImagesSurviveTheUpgradeFrom0F() throws {
        var version = DataMigrationVersion.version0F
        var urls = [try makeImageStore(version: version, images: imageCount)]

        while let next = version.nextVersion() {
            urls.append(try migrate(urls[urls.count - 1], from: version, to: next))
            version = next
        }

        XCTAssertEqual(version, DataMigrationVersion.current,
                       "nextVersion() stopped before the current model")
        XCTAssertEqual(try cachedUUIDs(at: urls[urls.count - 1], version: version, entityName: "Image"),
                       expectedUUIDs("image", imageCount),
                       "the upgrade from 0F did not carry every image to \(version.rawValue)")

        for url in urls {
            NSPersistentStoreCoordinator.destroyStore(at: url)
        }
    }

    // MARK: - Album

    /// No step carrying an Album policy adds or drops albums.
    func testAlbumsSurviveEachStepUnchanged() throws {
        for (source, destination) in Self.albumSteps {
            let sourceURL = try makeAlbumStore(version: source, albums: albumCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)
            XCTAssertEqual(try cachedUUIDs(at: destinationURL, version: destination, entityName: "Album"),
                           expectedUUIDs("album", albumCount),
                           """
                           \(source.rawValue) ► \(destination.rawValue) changed the \
                           number of albums. A policy creating its own destination \
                           instance must not call \
                           super.createDestinationInstances(forSource:in:manager:).
                           """)
            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     `comment` is optional up to `0F` and required from `0H` on, so `0F → 0H` has to put
     an empty `NSAttributedString` where the source held nil, exactly as the Image policy
     does for its own `title` and `comment`.
     */
    func testCommentIsFilledOnTheStepReaching0H() throws {
        let sourceURL = try makeAlbumStore(version: .version0F, albums: albumCount)
        let destinationURL = try migrate(sourceURL, from: .version0F, to: .version0H)

        try withRows(at: destinationURL, version: .version0H, entityName: "Album") { albums in
            XCTAssertEqual(albums.count, albumCount)
            for album in albums {
                XCTAssertNotNil(album.value(forKey: "comment") as? NSAttributedString,
                                "0F ► 0H left comment nil, which 0H forbids")
            }
        }

        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
        NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
    }

    /**
     `0L` splits the album description in three: the `comment` attributed string it
     already had, the plain `commentStr` the policy derives from it, and an empty
     `commentHTML`. All three are required, and only the migration can fill the last two.
     */
    func testCommentStringsAreDerivedByTheStepsReaching0L() throws {
        for source in [DataMigrationVersion.version0J, .version0K] {
            let sourceURL = try makeAlbumStore(version: source, albums: albumCount)
            let destinationURL = try migrate(sourceURL, from: source, to: .version0L)

            try withRows(at: destinationURL, version: .version0L, entityName: "Album") { albums in
                XCTAssertEqual(albums.count, albumCount)
                for album in albums {
                    let comment = try XCTUnwrap(album.value(forKey: "comment") as? NSAttributedString)
                    XCTAssertEqual(album.value(forKey: "commentStr") as? String, comment.string,
                                   "\(source.rawValue) ► 0L did not derive commentStr from comment")
                    XCTAssertNotNil(album.value(forKey: "commentHTML") as? NSAttributedString,
                                    "\(source.rawValue) ► 0L left commentHTML nil, which 0L forbids")
                }
            }

            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /// `commentRaw` arrives with `0N`, is required, and is filled by the server later.
    func testCommentRawIsInitialisedByTheStepReaching0N() throws {
        let sourceURL = try makeAlbumStore(version: .version0L, albums: albumCount)
        let destinationURL = try migrate(sourceURL, from: .version0L, to: .version0N)

        try withRows(at: destinationURL, version: .version0N, entityName: "Album") { albums in
            XCTAssertEqual(albums.count, albumCount)
            for album in albums {
                XCTAssertEqual(album.value(forKey: "commentRaw") as? String, "",
                               "0L ► 0N left commentRaw unset, which 0N forbids")
            }
        }

        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
        NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
    }

    /// The whole chain a v3.2 upgrader runs, `0F` to the current model, step after step.
    func testAlbumsSurviveTheUpgradeFrom0F() throws {
        var version = DataMigrationVersion.version0F
        var urls = [try makeAlbumStore(version: version, albums: albumCount)]

        while let next = version.nextVersion() {
            urls.append(try migrate(urls[urls.count - 1], from: version, to: next))
            version = next
        }

        XCTAssertEqual(version, DataMigrationVersion.current,
                       "nextVersion() stopped before the current model")
        XCTAssertEqual(try cachedUUIDs(at: urls[urls.count - 1], version: version, entityName: "Album"),
                       expectedUUIDs("album", albumCount),
                       "the upgrade from 0F did not carry every album to \(version.rawValue)")

        for url in urls {
            NSPersistentStoreCoordinator.destroyStore(at: url)
        }
    }

    // MARK: - Tag

    /// No step carrying a Tag policy adds or drops tags.
    func testTagsSurviveEachStepUnchanged() throws {
        for (source, destination) in Self.tagSteps {
            let sourceURL = try makeTagStore(version: source, tags: tagCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)
            XCTAssertEqual(try cachedTagNames(at: destinationURL, version: destination),
                           expectedTagNames(tagCount),
                           """
                           \(source.rawValue) ► \(destination.rawValue) changed the \
                           number of tags, or lost the name of one.
                           """)
            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     `0O → 0P` renames `tagId` to `pwgID` and `tagName` to `name`, and both values have
     to arrive intact.

     Xcode has no record of a renamed attribute unless the destination model carries a
     `renamingIdentifier`, so regenerating this mapping model makes it guess the source
     key. On 2026-08-21 it guessed `Tag.pwgID ← $source.id`, a key no `0O` tag has.
     `MigrationChainTests` now catches a key path which the source model does not
     define; this catches a key path which exists but holds the wrong value.
     */
    func testTagIdentifiersAreRenamedBy0OTo0P() throws {
        let sourceURL = try makeTagStore(version: .version0O, tags: tagCount)
        let destinationURL = try migrate(sourceURL, from: .version0O, to: .version0P)

        try withRows(at: destinationURL, version: .version0P, entityName: "Tag") { tags in
            XCTAssertEqual(tags.count, tagCount)
            let byName = Dictionary(uniqueKeysWithValues: try tags.map {
                (try XCTUnwrap($0.value(forKey: "name") as? String), $0)
            })
            for index in 0..<tagCount {
                let tag = try XCTUnwrap(byName["tag-\(index)"],
                                       "0O ► 0P lost the tagName of tag \(index)")
                XCTAssertEqual(tag.value(forKey: "pwgID") as? Int32, Int32(index + 100),
                               "0O ► 0P did not carry tagId into pwgID")
            }
        }

        NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
        NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
    }

    /// The whole chain from `09`, the oldest model holding tags, to the current one.
    func testTagsSurviveTheUpgradeFrom09() throws {
        var version = DataMigrationVersion.version09
        var urls = [try makeTagStore(version: version, tags: tagCount)]

        while let next = version.nextVersion() {
            urls.append(try migrate(urls[urls.count - 1], from: version, to: next))
            version = next
        }

        XCTAssertEqual(version, DataMigrationVersion.current,
                       "nextVersion() stopped before the current model")
        XCTAssertEqual(try cachedTagNames(at: urls[urls.count - 1], version: version),
                       expectedTagNames(tagCount),
                       "the upgrade from 09 did not carry every tag to \(version.rawValue)")

        for url in urls {
            NSPersistentStoreCoordinator.destroyStore(at: url)
        }
    }

    // MARK: - Sizes

    /// No step carrying a Sizes policy adds or drops a set of sizes.
    func testSizesSurviveEachStepUnchanged() throws {
        for (source, destination) in Self.sizesSteps {
            let sourceURL = try makeSizesStore(version: source, sizes: sizesCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)
            XCTAssertEqual(try cachedSquareWidths(at: destinationURL, version: destination),
                           expectedSquareWidths(sizesCount),
                           """
                           \(source.rawValue) ► \(destination.rawValue) changed the \
                           number of cached sizes, or lost the square of one.
                           """)
            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /**
     Every size survives its step with the pixels it was given.

     A `Resolution` reaches the store through `ResolutionValueTransformer`, so a step
     copies it by archiving and unarchiving it rather than by moving a scalar. Nothing
     in the mapping model states the type, which is why this has to be migrated to be
     checked: `MigrationChainTests` accepts any value class an expression yields for a
     transformable attribute it cannot type.
     */
    func testResolutionsKeepTheirPixelsThroughEveryStep() throws {
        for (source, destination) in Self.sizesSteps {
            let sourceURL = try makeSizesStore(version: source, sizes: sizesCount)
            let destinationURL = try migrate(sourceURL, from: source, to: destination)

            try withRows(at: destinationURL, version: destination, entityName: "Sizes") { rows in
                XCTAssertEqual(rows.count, sizesCount)
                for row in rows {
                    let square = try XCTUnwrap(row.value(forKey: "square") as? Resolution,
                                              "\(source.rawValue) ► \(destination.rawValue) lost the square")
                    let index = (square.width - 1_000) / 100
                    for (rank, name) in Self.sizeNames.enumerated() {
                        let resolution = try XCTUnwrap(row.value(forKey: name) as? Resolution,
                                                      "\(source.rawValue) ► \(destination.rawValue) lost \(name)")
                        XCTAssertEqual(resolution.width, Self.width(row: index, rank: rank),
                                       "\(source.rawValue) ► \(destination.rawValue) changed the width of \(name)")
                        XCTAssertEqual(resolution.height, Self.height(row: index, rank: rank),
                                       "\(source.rawValue) ► \(destination.rawValue) changed the height of \(name)")
                    }
                }
            }

            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /// `0N` adds two larger sizes, which the steps reaching it seed with a 1×1 resolution.
    func testLargerSizesAreInitialisedByTheStepsReaching0N() throws {
        for source in [DataMigrationVersion.version0L, .version0M] {
            let sourceURL = try makeSizesStore(version: source, sizes: sizesCount)
            let destinationURL = try migrate(sourceURL, from: source, to: .version0N)

            try withRows(at: destinationURL, version: .version0N, entityName: "Sizes") { rows in
                XCTAssertEqual(rows.count, sizesCount)
                for row in rows {
                    for name in ["xxxlarge", "xxxxlarge"] {
                        let resolution = try XCTUnwrap(row.value(forKey: name) as? Resolution,
                                                      "\(source.rawValue) ► 0N left \(name) nil")
                        XCTAssertEqual(resolution.width, 1)
                        XCTAssertEqual(resolution.height, 1)
                    }
                }
            }

            NSPersistentStoreCoordinator.destroyStore(at: sourceURL)
            NSPersistentStoreCoordinator.destroyStore(at: destinationURL)
        }
    }

    /// The whole chain from `0C`, the oldest model holding a Sizes, to the current one.
    func testSizesSurviveTheUpgradeFrom0C() throws {
        var version = DataMigrationVersion.version0C
        var urls = [try makeSizesStore(version: version, sizes: sizesCount)]

        while let next = version.nextVersion() {
            urls.append(try migrate(urls[urls.count - 1], from: version, to: next))
            version = next
        }

        XCTAssertEqual(version, DataMigrationVersion.current,
                       "nextVersion() stopped before the current model")
        XCTAssertEqual(try cachedSquareWidths(at: urls[urls.count - 1], version: version),
                       expectedSquareWidths(sizesCount),
                       "the upgrade from 0C did not carry every set of sizes to \(version.rawValue)")

        for url in urls {
            NSPersistentStoreCoordinator.destroyStore(at: url)
        }
    }
}
