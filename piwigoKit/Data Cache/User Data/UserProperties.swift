//
//  UserProperties.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 03/03/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation

/**
 A struct for managing user accounts
*/
public struct UserProperties: Sendable
{
    public let pwgID: Int16                         // Piwigo user ID
    public let username: String                     // Username
    public var name: String                         // User's name
    public let email: String                        // User's email
    public let status: String                       // See pwgUserStatus
    
    public let recentPeriod: Int16                  // Recent period in number of days
    public let registrationDate: TimeInterval       // Date of account creation
    public var lastUsed: TimeInterval               // Last time the account was used
    
    public var uploadRights: String                 // Allowed to upload
    public var downloadRights: Bool                 // Allowed to download
}
