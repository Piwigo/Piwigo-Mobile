//
//  NSManagedObjectContext+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

// MARK: - Core Data Batch Deletion
extension NSManagedObjectContext {
    /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
    public func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        do {
            // Execute the request.
            let deleteResult = try execute(batchDeleteRequest) as? NSBatchDeleteResult
            
            // Extract the IDs of the deleted managed objects from the request's result.
            if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                // Merge the deletions into the app's managed object context.
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [DataController.shared.mainContext]
                )
            }
        } catch {
            // Handle any thrown errors.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
}
