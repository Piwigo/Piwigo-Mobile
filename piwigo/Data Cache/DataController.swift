//
//  DataController.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 17/02/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

@objc
class DataController: NSObject {

    private override init() {
    }

    @objc
    class func getContext () -> NSManagedObjectContext {
        return DataController.managedObjectContext
    }
    
    @objc
    class func getPrivateContext () -> NSManagedObjectContext {
        return DataController.privateManagedObjectContext
    }
    
    
    // MARK: - Core Data stack
    
    static var managedObjectContext: NSManagedObjectContext = {

        var applicationDocumentsDirectory: URL = {
            // The directory the application uses to store the Core Data store file. This code uses a directory named "com.piwigo.…" in the application's documents Application Support directory.
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            print(urls[urls.count-1])
            return urls[urls.count-1]
        }()

        var managedObjectModel: NSManagedObjectModel = {
            // This resource is the same name as your xcdatamodeld contained in your project
            let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd")!
            return NSManagedObjectModel(contentsOf: modelURL)!
        }()

        var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
            // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
            // Create the coordinator and store
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            let url = applicationDocumentsDirectory.appendingPathComponent("DataModel.sqlite")
            var failureReason = "There was an error creating or loading the application's saved data."
            do {
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
            } catch {
                // Report any error we got.
                var dict = [String: AnyObject]()
                dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
                dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?

                dict[NSUnderlyingErrorKey] = error as NSError
                let wrappedError = NSError(domain: "piwigo.org", code: 9999, userInfo: dict)
                // Replace this with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
                abort()
            }

            return coordinator
        }()

        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        managedObjectContext.shouldDeleteInaccessibleFaults = true
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
        managedObjectContext.undoManager = nil
        return managedObjectContext
    }()

    static var privateManagedObjectContext: NSManagedObjectContext = {

        var privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        privateManagedObjectContext.parent = managedObjectContext
        return privateManagedObjectContext
    }()

    
    // MARK: - Core Data Saving support

    @objc
    class func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
}
