//
//  UploadToUploadMigrationPolicy_Copy.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 09/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation

class UploadToUploadMigrationPolicy_Copy: NSEntityMigrationPolicy {
    // Constants
    let logPrefix = "Upload ► Upload (Copy)"
    
    override func begin(_ mapping: NSEntityMapping, with manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Starting… (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }

    override func endInstanceCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Instances created (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    override func endRelationshipCreation(forMapping mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Relationships created (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
    
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        // Logs
        if #available(iOSApplicationExtension 14.0, *) {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.percent
            let percent = numberFormatter.string(from: NSNumber(value: manager.migrationProgress)) ?? ""
            DataMigrator.logger.notice("\(self.logPrefix): Completed (\(percent))")
        }
        // Progress bar
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: manager.migrationProgress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
}
