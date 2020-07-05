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
    class func getContext() -> NSManagedObjectContext {
        return DataController.managedObjectContext
    }
    
    @objc
    class func getPrivateContext() -> NSManagedObjectContext {
        return DataController.privateManagedObjectContext
    }
    
    class func getApplicationStoresDirectory() -> URL {
        return DataController.applicationStoresDirectory
    }
    
    
    // MARK: - Core Data stack
    
    static var applicationStoresDirectory: URL = {
        let fm = FileManager.default
        let applicationName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
        let applicationSupportDirectory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).last
        let storesURL = applicationSupportDirectory?.appendingPathComponent(applicationName)
        print("== Piwigo Stores ==>\(storesURL!)")

        // Create the Stores directory if needed
        if !(fm.fileExists(atPath: storesURL?.path ?? "")) {
            var errorCreatingDirectory: Error? = nil
            do {
                if let storesURL = storesURL {
                    try fm.createDirectory(at: storesURL, withIntermediateDirectories: true, attributes: nil)
                }
            } catch let errorCreatingDirectory {
            }
            if errorCreatingDirectory != nil {
                print("Unable to create Stores directory in Application Support.")
                abort()
            }
        }

        return storesURL!
    }()

    static var managedObjectContext: NSManagedObjectContext = {

        var applicationDocumentsDirectory: URL = {
            // The directory the application uses to store the Core Data store file.
            // This code uses a directory named "com.piwigo.…" in the application's documents Application Support directory.
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            return urls[urls.count-1]
        }()

        var applicationIncompatibleStoresDirectory: URL = {
            let fm = FileManager.default
            let anURL = applicationStoresDirectory.appendingPathComponent("Incompatible")

            // Create the Piwigo/Incompatible directory if needed
            if !fm.fileExists(atPath: anURL.path) {
                var errorCreatingDirectory: Error? = nil
                do {
                    try fm.createDirectory(at: anURL, withIntermediateDirectories: true, attributes: nil)
                } catch let errorCreatingDirectory {
                }

                if errorCreatingDirectory != nil {
                    print("Unable to create directory for corrupt data stores.")
                    abort()
                }
            }

            return anURL
        }()

        var nameForIncompatibleStore: String = {
            // Initialize Date Formatter
            let dateFormatter = DateFormatter()

            // Configure Date Formatter
            dateFormatter.formatterBehavior = .behavior10_4
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

            return "\(dateFormatter.string(from: Date())).sqlite"
        }()

        var managedObjectModel: NSManagedObjectModel = {
            // This resource is the same name as your xcdatamodeld contained in your project
            let modelURL = Bundle.main.url(forResource: "DataModel", withExtension: "momd")!
            return NSManagedObjectModel(contentsOf: modelURL)!
        }()

        var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
            // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
            // Create the coordinator
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
            let oldURL = applicationDocumentsDirectory.appendingPathComponent("DataModel.sqlite")
            let storeURL = applicationStoresDirectory.appendingPathComponent("DataModel.sqlite")
            let fm = FileManager.default
            if (fm.fileExists(atPath: oldURL.path)) {
                // Old location => Move the store to the Stores directory
                var errorMoveStore: Error? = nil
                do {
                    // Move file to "Application Support/Stores" directory
                    try fm.moveItem(at: oldURL, to: storeURL)
                }
                catch let errorMoveStore {
                }
                if errorMoveStore != nil {
                    // Could not move the file… Ok, we abandon as it concerns very few users
                    print("Unable to move store to Application Support/Stores directory.")
                }
            }

            // See https://code.tutsplus.com/tutorials/core-data-from-scratch-migrations--cms-21844 for migrating to a new data model
            var failureReason = "There was an error creating or loading the application's saved data."
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
                NSInferMappingModelAutomaticallyOption: NSNumber(value: true)
            ]
            do {
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
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

                // Move Incompatible Store
                if fm.fileExists(atPath: storeURL.path) {
                    let corruptURL = applicationIncompatibleStoresDirectory.appendingPathComponent(nameForIncompatibleStore)

                    // Move Corrupt Store
                    var errorMoveStore: Error? = nil
                    do {
                        try fm.moveItem(at: storeURL, to: corruptURL)
                    } catch let errorMoveStore {
                    }

                    if errorMoveStore != nil {
                        print("Unable to move corrupt store.")
                    }
                }
                
                // Will inform user at restart
                Model.sharedInstance()?.couldNotMigrateCoreDataStore = true
                Model.sharedInstance()?.saveToDisk()

                // Crash!
                abort()
            }

            return coordinator
        }()

        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        if #available(iOS 10.0, *) {
            managedObjectContext.automaticallyMergesChangesFromParent = true
        } else {
            // Fallback on earlier versions
        }
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
        privateManagedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        privateManagedObjectContext.shouldDeleteInaccessibleFaults = true
        // Set unused undoManager to nil for macOS (it is nil by default on iOS)
        // to reduce resource requirements.
//        privateManagedObjectContext.undoManager = nil
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
