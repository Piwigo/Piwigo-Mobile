//
//  CacheVarsObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class CacheVarsObjc: NSObject {

    // Singleton
    @objc static let shared = CacheVarsObjc()
    
    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Data cache variables stored in UserDefaults / Standard
    /// - Core Data migration issue
//    @UserDefault("couldNotMigrateCoreDataStore", defaultValue: false)
    @objc var couldNotMigrateCoreDataStore: Bool {
        get { return CacheVars.shared.couldNotMigrateCoreDataStore }
        set (value) { CacheVars.shared.couldNotMigrateCoreDataStore = value }
    }

    // MARK: - Vars in UserDefaults / App Group
    // Data cache variables stored in UserDefaults / App Group
    /// - none


    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - none


    // MARK: - Functions
    @objc class func saveContextObjc() {
        DataController.saveContext()
    }
}
