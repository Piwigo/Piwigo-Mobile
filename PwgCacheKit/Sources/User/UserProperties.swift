//
//  UserProperties.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 03/03/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import Foundation
import PwgKit

/**
 A struct for managing user accounts
*/
public struct UserProperties: Sendable
{
    public var pwgID: Int16                         // Piwigo user ID
    public var login: String                        // Username or API public key
    public var username: String                     // User's account name
    public var name: String                         // User's name
    public var email: String                        // User's email
    public var status: String                       // See pwgUserStatus
    
    public var recentPeriod: Int16                  // Recent period in number of days
    public var registrationDate: TimeInterval       // Date of account creation
    public var lastUsed: TimeInterval               // Last time the account was accessed
    
    public var createAlbumRights: String            // Allowed to create albums in album IDs
    public var uploadRights: String                 // Allowed to upload in album IDs
    public var downloadRights: Bool                 // Allowed to download
    
    public var userURIstr: String                   // User instance URI string
}


extension UserProperties
{
    public init(withStatus status: pwgUserStatus) {
        self.init(pwgID: Int16.min, login: "", username: "", name: "", email: "",
                  status: pwgUserStatus.guest.rawValue, recentPeriod: 7,
                  registrationDate: Date.distantPast.timeIntervalSinceReferenceDate,
                  lastUsed: Date.distantPast.timeIntervalSinceReferenceDate,
                  createAlbumRights: "", uploadRights: "", downloadRights: false,
                  userURIstr: "")
    }
    
    public var role: pwgUserStatus {
        return pwgUserStatus(rawValue: self.status) ?? .guest
    }
    
    public var hasAdminRights: Bool {
        return [.webmaster, .admin].contains(self.role)
    }
}
