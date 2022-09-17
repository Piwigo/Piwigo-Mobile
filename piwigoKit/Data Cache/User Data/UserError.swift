//
//  UserError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum UserError: Error {
    case emptyUsername
    case unknownUserStatus
    case creationError
}

extension UserError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyUsername:
            return NSLocalizedString("CoreDataFetch_UserMissingData",
                                     comment: "Will discard a user account missing a valid username.")
        case .unknownUserStatus:
            return NSLocalizedString("CoreDataFetch_UserUnknownStatus",
                                     comment: "Will discard a user account missing a valid user status.")
        case .creationError:
            return NSLocalizedString("CoreData_UserCreateFailed",
                                     comment: "Failed to create a new User object.")
        }
    }
}
