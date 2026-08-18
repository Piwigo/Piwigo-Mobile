//
//  MigrationChainTests.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 18 August 2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import CoreData
import XCTest
@testable import PwgCacheKit

/**
 Guards the Core Data migration chain against silently degrading to lightweight
 inference.

 A `.xcmappingmodel` embeds a snapshot of its source and destination models, and
 Core Data selects it by comparing the entity version hashes in that snapshot
 against the compiled models. Editing a `.xcdatamodel` after the mapping model
 was generated — or letting Xcode rewrite the mapping model, which drops the
 migration policy class names — leaves the step working but running through
 `NSMappingModel.inferredMappingModel`, so the policies never run: no progress
 reporting, no cancellation, and no custom attribute conversion. Nothing warns
 at build time and nothing fails at runtime.

 That went unnoticed for over a year on `0H → 0J`, where
 `UploadToUploadMigrationPolicy_0H_to_0J` converts `prefixFileNameBeforeUpload`
 and `defaultPrefix` into `fileNamePrefixEncodedActions`: upgraders from v3.3
 lost their filename-prefix settings.

 `Scripts/audit-mapping-models.sh` checks the same invariant without a
 simulator, and reports which entity drifted.
 */
final class MigrationChainTests: XCTestCase {

    // MARK: - Expectations

    /**
     Steps that deliberately carry no `.xcmappingmodel` and migrate by
     lightweight inference. Anything not listed here must resolve a custom
     mapping model, so a newly added step has to be classified one way or the
     other rather than quietly falling back to inference.
     */
    private static let inferenceOnlySteps: Set<String> = [
        "01→02", "02→03", "03→04", "04→05", "05→06", "06→07", "07→08", "08→09",
        "0C→0F", "0D→0F", "0E→0F",
    ]

    /**
     Number of entity mappings that carry an `NSEntityMigrationPolicy` for each
     step that has a custom mapping model. Pinned so that a regenerated mapping
     model missing its policy class names fails the build instead of shipping.

     Update a number here only when the mapping model legitimately changes, and
     remember that the total entity-mapping count grows with the model: a newly
     introduced entity has no source instances, so it gets no entity mapping in
     the step that introduces it (`UserGroup` in `0H → 0J`).
     */
    private static let expectedPolicyCount: [String: Int] = [
        "09→0C": 3,
        "0A→0B": 0,     // predates the …MigrationPolicy_Copy convention
        "0B→0C": 7,     // Sizes was introduced here, so it has no entity mapping
        "0F→0H": 8,
        "0G→0H": 8,
        "0H→0J": 8,     // UserGroup introduced here
        "0I→0J": 8,
        "0J→0L": 9,
        "0K→0L": 9,
        "0L→0N": 9,
        "0M→0N": 9,
        "0N→0O": 9,
        "0O→0P": 9,
    ]

    // MARK: - Helpers

    /// Every `sourceVersion → destinationVersion` pair in `nextVersion()`.
    private static var chain: [(source: DataMigrationVersion, destination: DataMigrationVersion)] {
        DataMigrationVersion.allCases.compactMap { version in
            version.nextVersion().map { (version, $0) }
        }
    }

    private static func key(_ source: DataMigrationVersion,
                            _ destination: DataMigrationVersion) -> String {
        "\(Self.shortName(source))→\(Self.shortName(destination))"
    }

    /// "DataModel 0J (Group)" -> "0J"
    private static func shortName(_ version: DataMigrationVersion) -> String {
        let parts = version.rawValue.split(separator: " ")
        return parts.count >= 2 ? String(parts[1]) : version.rawValue
    }

    /**
     Resolves the custom mapping model for a step, or `nil` when the step falls
     back to inference.

     `NSMappingModel(from:forSourceModel:destinationModel:)` ignores the bundles
     it is handed once the bundle holding the compiled `.cdm` files has been
     constructed anywhere in the process — it then finds them via the loaded
     bundles, so even `nil` succeeds. Loading the models through
     `managedObjectModel(forVersion:)` first is what registers PwgCacheKit's
     resource bundle, exactly as `DataMigrationStep.init` does in the app.
     */
    private func customMappingModel(from source: DataMigrationVersion,
                                    to destination: DataMigrationVersion) -> NSMappingModel? {
        let sourceModel = NSManagedObjectModel.managedObjectModel(forVersion: source)
        let destinationModel = NSManagedObjectModel.managedObjectModel(forVersion: destination)
        return NSMappingModel(from: nil,
                              forSourceModel: sourceModel,
                              destinationModel: destinationModel)
    }

    // MARK: - Tests

    /// Every step is explicitly either custom-mapped or inference-only.
    func testEveryStepIsClassified() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            let isCustom = Self.expectedPolicyCount[key] != nil
            let isInferred = Self.inferenceOnlySteps.contains(key)
            XCTAssertNotEqual(isCustom, isInferred,
                              """
                              Step \(key) is not classified. Add it to \
                              expectedPolicyCount if it has a .xcmappingmodel, \
                              or to inferenceOnlySteps if it migrates by \
                              lightweight inference.
                              """)
        }
    }

    /// Steps that are supposed to have a mapping model actually resolve one.
    func testCustomMappingModelsAreNotOrphaned() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard Self.expectedPolicyCount[key] != nil else { continue }
            XCTAssertNotNil(customMappingModel(from: source, to: destination),
                            """
                            Step \(key) has no matching mapping model, so it \
                            silently migrates by lightweight inference. Either \
                            its .xcmappingmodel is orphaned by an edit to the \
                            \(Self.shortName(destination)) model, or its \
                            .process(…) line is missing from Package.swift. \
                            Run Scripts/audit-mapping-models.sh.
                            """)
        }
    }

    /// Regenerating a mapping model in Xcode drops its policy class names.
    func testMappingModelsKeepTheirMigrationPolicies() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard let expected = Self.expectedPolicyCount[key],
                  let mappingModel = customMappingModel(from: source, to: destination)
            else { continue }

            let policies = mappingModel.entityMappings
                .compactMap(\.entityMigrationPolicyClassName)
            XCTAssertEqual(policies.count, expected,
                           """
                           Step \(key) declares \(policies.count) migration \
                           policies, expected \(expected). Xcode drops policy \
                           class names when it rewrites a mapping model — \
                           restore them with \
                           Scripts/copy-migration-policies.py.
                           """)
        }
    }

    /**
     Same expectation as `testMappingModelsKeepTheirMigrationPolicies`, but
     resolved through `DataMigrationStep` — the app's own lookup — so an orphaned
     mapping model or a lost policy name is caught on the production path and not
     only in this suite's own reimplementation of it.

     It cannot verify which bundle that lookup searches. `NSMappingModel(from:)`
     falls back to every bundle already loaded in the process, and
     `DataMigrationStep.init` loads both models through `Bundle.module` first,
     which registers the bundle holding the `.cdm` files. Measured on
     2026-08-18: this test still passes with the lookup pointed at
     `Bundle(for: DataController.self)`, which contains no `.cdm` at all.
     Catching that would need a fresh process with the bundle unregistered,
     which XCTest cannot arrange. The comment in `customMappingModel(…)` is what
     guards it.
     */
    func testAppLookupResolvesCustomMappingModels() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard let expected = Self.expectedPolicyCount[key] else { continue }

            let step = DataMigrationStep(sourceVersion: source, destinationVersion: destination)
            let policies = step.mappingModel.entityMappings
                .compactMap(\.entityMigrationPolicyClassName)
            XCTAssertEqual(policies.count, expected,
                           """
                           DataMigrationStep resolved \(policies.count) \
                           migration policies for \(key), expected \(expected). \
                           It fell back to lightweight inference, so either the \
                           mapping model is orphaned or customMappingModel(…) \
                           is searching the wrong bundle.
                           """)
        }
    }

    /// Inference-only steps must at least be migratable.
    func testInferenceOnlyStepsCanBeInferred() {
        for (source, destination) in Self.chain {
            guard Self.inferenceOnlySteps.contains(Self.key(source, destination)) else { continue }
            let sourceModel = NSManagedObjectModel.managedObjectModel(forVersion: source)
            let destinationModel = NSManagedObjectModel.managedObjectModel(forVersion: destination)
            XCTAssertNoThrow(try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                                     destinationModel: destinationModel),
                             "Step \(Self.key(source, destination)) cannot be inferred and has no mapping model.")
        }
    }

    /// The chain must reach the newest model version from every entry point.
    func testChainReachesCurrentVersion() {
        for version in DataMigrationVersion.allCases {
            var current = version
            var visited: Set<DataMigrationVersion> = [current]
            while let next = current.nextVersion() {
                XCTAssertTrue(visited.insert(next).inserted,
                              "nextVersion() loops at \(Self.shortName(next)).")
                current = next
            }
            XCTAssertEqual(current, .current,
                           """
                           \(Self.shortName(version)) stops at \
                           \(Self.shortName(current)) instead of reaching \
                           \(Self.shortName(.current)). Add a nextVersion() \
                           entry for it.
                           """)
        }
    }
}
