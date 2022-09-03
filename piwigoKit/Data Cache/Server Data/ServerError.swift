//
//  ServerError.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 21/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation

public enum ServerError: Error {
    case wrongURL
    case creationError
}

extension ServerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .wrongURL:
            return NSLocalizedString("serverURLerror_title", comment: "Incorrect URL")
        case .creationError:
            return NSLocalizedString("CoreData_ServerCreateFailed",
                                     comment: "Failed to create a new Server object.")
        }
    }
}
