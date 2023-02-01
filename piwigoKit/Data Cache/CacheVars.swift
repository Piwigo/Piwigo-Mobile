//
//  CacheVars.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 06/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation

public class CacheVars: NSObject {

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
    @UserDefault("couldNotMigrateCoreDataStore", defaultValue: false)
    public static var couldNotMigrateCoreDataStore: Bool


    // MARK: - Vars in UserDefaults / App Group
    // Network variables stored in UserDefaults / App Group
    /// - none


    // MARK: - Vars in Memory
    // Variables kept in memory
    /// - none
}
