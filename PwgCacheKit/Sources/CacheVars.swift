//
//  CacheVars.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 06/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

// Mark CacheVars as Sendable since Apple documents UserDefaults as thread-safe
public class CacheVars: @unchecked Sendable {
    
    // Singleton
    public static let shared = CacheVars()
    
    // Remove deprecated stored objects if needed
    init() {
        // Deprecated data?
        if let _ = UserDefaults.standard.object(forKey: "couldNotMigrateCoreDataStore") {
            UserDefaults.standard.removeObject(forKey: "couldNotMigrateCoreDataStore")
        }
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
    }
    
    // MARK: - Vars in UserDefaults / Standard
    // Data cache variables stored in UserDefaults / Standard
    /// None
    
    
    // MARK: - Vars in UserDefaults / App Group
    // Variables stored in UserDefaults / App Group
    /// - List of albums recently visited / used
    @UserDefault("recentCategories", defaultValue: "0")
    public var recentCategories: String
    
    /// - Maximum number of recent abums  presented to the user
    @UserDefault("maxNberRecentCategories", defaultValue: 5)
    public var maxNberRecentCategories: Int
    
    
    // MARK: - Vars in Memory
    // Variables kept in memory
    /// To prevent Core Data usage until the database migration is finished.
    public var isMigrationRunning: Bool = false
}
