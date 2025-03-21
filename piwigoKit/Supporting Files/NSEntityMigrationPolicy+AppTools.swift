//
//  NSEntityMigrationPolicy+AppTools.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 14/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation
import CoreData

extension NSEntityMigrationPolicy {
    
    // Updates the progress bar of the DataMigrationViewController
    func updateProgressBar(_ progress: Float) {
        DispatchQueue.main.async {
            let userInfo = ["progress" : NSNumber.init(value: progress)]
            NotificationCenter.default.post(name: Notification.Name.pwgMigrationProgressUpdated,
                                            object: nil, userInfo: userInfo)
        }
    }
}
