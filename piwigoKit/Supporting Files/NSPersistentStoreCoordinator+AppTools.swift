//
//  NSPersistentStoreCoordinator+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/06/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

extension NSPersistentStoreCoordinator {

    static func destroyStore(at storeURL: URL) {
        do {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try psc.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
        } catch let error {
            fatalError("failed to destroy persistent store at \(storeURL), error: \(error)")
        }
    }
    
    static func moveStore(from sourceURL: URL, to targetURL: URL) {
        let psc = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
        if let sourceStore = psc.persistentStore(for: sourceURL) {
            do {
                try psc.migratePersistentStore(sourceStore, to: targetURL,
                                               options: nil, withType: NSSQLiteStoreType)
                destroyStore(at: sourceURL)
            } catch let error {
                fatalError("failed to move from: \(sourceURL) to \(targetURL), error: \(error)")
            }
        }
    }
    
    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) {
        do {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try psc.replacePersistentStore(at: targetURL, destinationOptions: nil,
                                           withPersistentStoreFrom: sourceURL,
                                           sourceOptions: nil, ofType: NSSQLiteStoreType)
        } catch let error {
            fatalError("failed to replace persistent store at \(targetURL) with \(sourceURL), error: \(error)")
        }
    }
    
    static func metadata(at storeURL: URL) -> [String : Any]?  {
        return try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                                                            at: storeURL, options: nil)
    }
    
    func addPersistentStore(at storeURL: URL, options: [AnyHashable : Any]) -> NSPersistentStore {
        do {
            return try addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                          at: storeURL, options: options)
        } catch let error {
            fatalError("failed to add persistent store to coordinator, error: \(error)")
        }
    }
}
