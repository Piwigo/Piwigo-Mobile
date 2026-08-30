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
    /**
     Every policy class a mapping model names has to exist at runtime.

     `entityMigrationPolicyClassName` is a plain string in the compiled mapping
     model, so renaming or deleting a policy class leaves the mapping model
     pointing at nothing and the step only fails when a user upgrades through
     it. Includes the two mapping models still on disk that no chain step uses,
     since they name the same shared policies.
     */
    func testDeclaredMigrationPoliciesResolve() {
        let supersededSteps: [(DataMigrationVersion, DataMigrationVersion)] = [
            (.version0J, .version0K),   // superseded by 0J → 0L
            (.version0L, .version0M),   // superseded by 0L → 0N
        ]
        let steps = Self.chain.map { ($0.source, $0.destination) } + supersededSteps

        for (source, destination) in steps {
            guard let mappingModel = customMappingModel(from: source, to: destination) else { continue }
            for name in mappingModel.entityMappings.compactMap(\.entityMigrationPolicyClassName) {
                guard let policyClass = NSClassFromString(name) else {
                    XCTFail("""
                            Step \(Self.key(source, destination)) names migration \
                            policy \(name), which does not exist. Rename it back or \
                            update the mapping models naming it.
                            """)
                    continue
                }
                XCTAssertTrue(policyClass is NSEntityMigrationPolicy.Type,
                              "\(name) is not an NSEntityMigrationPolicy subclass")
            }
        }
    }

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

    /**
     Every constant a mapping model assigns must be storable in the attribute it
     targets.

     Xcode seeds the value expression of an attribute which is new in the
     destination model from that attribute's default value, taken verbatim from
     the `.xcdatamodel` XML — where every default is a string or a number. For a
     `Date` attribute declared with `defaultDateTimeInterval`, that yields a
     constant `NSNumber`, and Core Data throws
     `NSInvalidArgumentException: Unacceptable type of value for attribute` from
     `createDestinationInstancesForSourceInstance(…)` — mid-migration, on the
     user's store, with no way to resume.

     That happened on 2026-08-22 with `Album.shareCreationDate` in `0O → 0P`
     (constant `-3600` for a `Date`), and it is invisible to every other test
     here: the mapping model resolves, keeps its policies and matches the model
     hashes. The fix is to clear that value expression so the destination keeps
     the default it was given when Core Data inserted it.
     */
    func testMappingModelConstantsMatchTheirAttributeTypes() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard let mappingModel = customMappingModel(from: source, to: destination) else { continue }
            let destinationModel = NSManagedObjectModel.managedObjectModel(forVersion: destination)

            for entityMapping in mappingModel.entityMappings {
                guard let entityName = entityMapping.destinationEntityName,
                      let entity = destinationModel.entitiesByName[entityName]
                else { continue }

                for propertyMapping in entityMapping.attributeMappings ?? [] {
                    guard let name = propertyMapping.name,
                          let attribute = entity.attributesByName[name],
                          let expression = propertyMapping.valueExpression,
                          expression.expressionType == .constantValue
                    else { continue }

                    guard let value = expression.constantValue else {
                        XCTAssertTrue(attribute.isOptional,
                                      """
                                      \(key) assigns nil to the non-optional attribute \
                                      \(entityName).\(name).
                                      """)
                        continue
                    }
                    XCTAssertTrue(Self.isAcceptable(value, for: attribute.attributeType),
                                  """
                                  \(key) assigns the constant \(value) of type \(type(of: value)) \
                                  to \(entityName).\(name), which is not a \
                                  \(Self.name(of: attribute.attributeType)). Core Data throws while \
                                  creating the destination instances. Clear that value expression so \
                                  the attribute keeps its default value.
                                  """)
                }
            }
        }
    }

    /**
     Every `$source.<key>` a mapping model reads must exist in the source model.

     Xcode has no record of a renamed attribute unless the destination model
     carries a `renamingIdentifier`, so regenerating a mapping model makes it
     guess the source key — and the guess can be wrong. On 2026-08-21 it wrote
     `Tag.pwgID ← $source.id` while the `0O` attribute was `tagId`, which is a
     KVC lookup for an undefined key on every cached tag.

     Only the first segment of a key path is checked: deeper ones traverse
     relationships whose destination entity this test does not resolve.
     */
    func testMappingModelKeyPathsExistInTheSourceModel() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard let mappingModel = customMappingModel(from: source, to: destination) else { continue }
            let sourceModel = NSManagedObjectModel.managedObjectModel(forVersion: source)

            for entityMapping in mappingModel.entityMappings {
                guard let entityName = entityMapping.sourceEntityName,
                      let entity = sourceModel.entitiesByName[entityName]
                else { continue }

                for propertyMapping in entityMapping.attributeMappings ?? [] {
                    guard let name = propertyMapping.name,
                          let expression = propertyMapping.valueExpression,
                          expression.description.hasPrefix("$source.")
                    else { continue }

                    let keyPath = expression.description.dropFirst("$source.".count)
                    guard let first = keyPath.split(separator: ".").first.map(String.init)
                    else { continue }
                    XCTAssertTrue(entity.attributesByName[first] != nil
                                  || entity.relationshipsByName[first] != nil,
                                  """
                                  \(key) reads $source.\(keyPath) for \(name), but \(entityName) \
                                  has no '\(first)' in \(Self.shortName(source)). Xcode guesses the \
                                  source of a renamed attribute when the destination model carries no \
                                  renamingIdentifier for it.
                                  """)
                }
            }
        }
    }

    /// Whether a constant value can be stored in an attribute of that type.
    /// Transformable and unhandled types are accepted: their value class is arbitrary.
    private static func isAcceptable(_ value: Any, for type: NSAttributeType) -> Bool {
        switch type {
        case .dateAttributeType:        return value is Date
        case .stringAttributeType:      return value is String
        case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType,
             .doubleAttributeType, .floatAttributeType, .decimalAttributeType,
             .booleanAttributeType:     return value is NSNumber
        case .binaryDataAttributeType:  return value is Data
        case .UUIDAttributeType:        return value is UUID
        case .URIAttributeType:         return value is URL
        default:                        return true
        }
    }

    private static func name(of type: NSAttributeType) -> String {
        switch type {
        case .dateAttributeType:        return "Date"
        case .stringAttributeType:      return "String"
        case .integer16AttributeType:   return "Integer 16"
        case .integer32AttributeType:   return "Integer 32"
        case .integer64AttributeType:   return "Integer 64"
        case .doubleAttributeType:      return "Double"
        case .floatAttributeType:       return "Float"
        case .decimalAttributeType:     return "Decimal"
        case .booleanAttributeType:     return "Boolean"
        case .binaryDataAttributeType:  return "Binary Data"
        case .UUIDAttributeType:        return "UUID"
        case .URIAttributeType:         return "URI"
        case .transformableAttributeType: return "Transformable"
        default:                        return "attribute of type \(type.rawValue)"
        }
    }

    /**
     An attribute which is new in the destination model must either be mapped or
     be able to stand on its own once the destination instance is inserted.

     `mapc` silently discards an attribute mapping object which the entity
     mapping does not reference — `Album.shareCreationDate` is one, orphaned by
     Xcode when it regenerated `0O → 0P` — so a *missing* mapping looks exactly
     like a deliberately absent one, and the two other expression tests here can
     say nothing about it. Absent is fine as long as Core Data can insert the
     destination instance without it: the attribute is optional, or it carries a
     default value.

     Otherwise the migration inserts an instance with nothing in a mandatory
     attribute and fails validation while saving, which surfaces far from its
     cause.

     Entities handled by a step-specific policy are exempt: that policy may set
     the attribute itself, and only reading its code would tell.
     */
    func testNewAttributesAreMappedOrHaveADefault() {
        for (source, destination) in Self.chain {
            let key = Self.key(source, destination)
            guard let mappingModel = customMappingModel(from: source, to: destination) else { continue }
            let sourceModel = NSManagedObjectModel.managedObjectModel(forVersion: source)
            let destinationModel = NSManagedObjectModel.managedObjectModel(forVersion: destination)

            for entityMapping in mappingModel.entityMappings {
                guard let sourceName = entityMapping.sourceEntityName,
                      let sourceEntity = sourceModel.entitiesByName[sourceName],
                      let destinationName = entityMapping.destinationEntityName,
                      let destinationEntity = destinationModel.entitiesByName[destinationName]
                else { continue }

                // A step-specific policy may fill an attribute from its own code, which no
                // inspection of the models can see: ImageToImageMigrationPolicy_0J_to_0L and
                // AlbumToAlbumMigrationPolicy_0K_to_0L both set commentHTML that way. The
                // shared …MigrationPolicy_Copy classes only wrap super with progress reporting
                // and cancellation, so under them the mapping model is the whole truth.
                let policy = entityMapping.entityMigrationPolicyClassName
                guard policy == nil || policy!.hasSuffix("MigrationPolicy_Copy") else { continue }

                let mapped = Set((entityMapping.attributeMappings ?? []).compactMap(\.name))
                for (name, attribute) in destinationEntity.attributesByName {
                    // Attributes carried over keep their value; transient ones are not stored
                    guard sourceEntity.attributesByName[name] == nil,
                          attribute.isTransient == false,
                          mapped.contains(name) == false
                    else { continue }

                    XCTAssertTrue(attribute.isOptional || attribute.defaultValue != nil,
                                  """
                                  \(key) neither maps nor defaults \(destinationName).\(name), \
                                  which is new in \(Self.shortName(destination)) and mandatory. \
                                  Core Data inserts the destination instances before evaluating \
                                  the attribute mappings, so this one stays empty and the save \
                                  fails validation. Give it a default value in the model, or a \
                                  value expression referenced by its entity mapping.
                                  """)
                }
            }
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
