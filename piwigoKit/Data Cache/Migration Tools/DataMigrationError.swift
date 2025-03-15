//
//  DataMigrationError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 15/03/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

public enum DataMigrationError: Error {
    case timeout
}

extension DataMigrationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return NSLocalizedString("CoreData_MigrationError_timeout",
                                     comment: "The app was suspended while migrating the store. Please restart the app and try again.")
        }
    }
}
