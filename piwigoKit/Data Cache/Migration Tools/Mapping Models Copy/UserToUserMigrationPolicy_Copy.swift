//
//  UserToUserMigrationPolicy_Copy.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 09/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation

class UserToUserMigrationPolicy_Copy: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "User ► User (Copy)"
    let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.percent
        return numberFormatter
    }()

    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Starting… (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
    }

    override func endInstanceCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Instances created (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
    }
    
    override func endRelationshipCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Relationships created (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
    }
    
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Completed (\(percent))")
        }
        
        // Progress bar
        updateProgressBar(manager.migrationProgress)
    }
}
