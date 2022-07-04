//
//  DataMigrationStep.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

// MARK: - Core Data Migration Step
/// See: https://williamboles.com/progressive-core-data-migration/
struct DataMigrationStep {
    
    let sourceModel: NSManagedObjectModel
    let destinationModel: NSManagedObjectModel
    let mappingModel: NSMappingModel
    

    // MARK: - Initialisation
    init(sourceVersion: DataMigrationVersion, destinationVersion: DataMigrationVersion) {
        let sourceModel = NSManagedObjectModel.managedObjectModel(forVersion: sourceVersion)
        let destinationModel = NSManagedObjectModel.managedObjectModel(forVersion: destinationVersion)
        
        guard let mappingModel = DataMigrationStep.mappingModel(fromSourceModel: sourceModel,
                                                                toDestinationModel: destinationModel) else {
            fatalError("Expected modal mapping not present")
        }
        
        self.sourceModel = sourceModel
        self.destinationModel = destinationModel
        self.mappingModel = mappingModel
    }
    

    // MARK: - Mapping
    private static func mappingModel(fromSourceModel sourceModel: NSManagedObjectModel,
                                     toDestinationModel destinationModel: NSManagedObjectModel) -> NSMappingModel? {
        // First, search for a custom migration mapping existing in the bundle (Standard migration)
        guard let customMapping = customMappingModel(fromSourceModel: sourceModel,
                                                     toDestinationModel: destinationModel) else {
            // Try and infer a mapping model (Lightweight migration)
            return inferredMappingModel(fromSourceModel:sourceModel,
                                        toDestinationModel: destinationModel)
        }
        return customMapping
    }
    
    private static func inferredMappingModel(fromSourceModel sourceModel: NSManagedObjectModel,
                                             toDestinationModel destinationModel: NSManagedObjectModel) -> NSMappingModel? {
        return try? NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                        destinationModel: destinationModel)
    }
    
    private static func customMappingModel(fromSourceModel sourceModel: NSManagedObjectModel,
                                           toDestinationModel destinationModel: NSManagedObjectModel) -> NSMappingModel? {
        return NSMappingModel(from: [Bundle.main], forSourceModel: sourceModel,
                              destinationModel: destinationModel)
    }
}
