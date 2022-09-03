//
//  NSManagedObjectModel+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectModel {
    
    // MARK: - Resource
    static func managedObjectModel(forVersion version: DataMigrationVersion) -> NSManagedObjectModel {
        let mainBundle = Bundle(for: DataController.self)
        let subdirectory = "DataModel.momd"
        
        var omoURL: URL?
        if #available(iOS 11, *) {
            omoURL = mainBundle.url(forResource: version.rawValue, withExtension: "omo",
                                    subdirectory: subdirectory) // optimized model file
        }
        let momURL = mainBundle.url(forResource: version.rawValue, withExtension: "mom",
                                    subdirectory: subdirectory)
        
        guard let url = omoURL ?? momURL else {
            fatalError("unable to find model in bundle")
        }
        
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("unable to load model in bundle")
        }
        
        return model
    }


    // MARK: - Compatible
    static func compatibleModelForStoreMetadata(_ metadata: [String : Any]) -> NSManagedObjectModel? {
        let mainBundle = Bundle(for: DataController.self)
        return NSManagedObjectModel.mergedModel(from: [mainBundle], forStoreMetadata: metadata)
    }
}
