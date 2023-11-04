//
//  User+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData

/* User instances represent user accounts of a Piwigo server.
    - Instances are associated to a Server instance and differentiate with usernames.
    - Because album contents depend on user rights, each instance contains albums only belong to it.
    - Instances share images whose access is defined by album data.
    - Each instance contains upload requests only belonging to it.
 */
public class User: NSManagedObject {
    
    /**
     Updates the attributes of a User Account instance.
     */
    func update(username: String, ofServer server: Server,
                userStatus: pwgUserStatus = NetworkVars.userStatus,
                withName name: String = "", lastUsed: Date = Date()) throws {
        // Check user's status
        guard pwgUserStatus.allCases.contains(userStatus) else {
            throw UserError.unknownUserStatus
        }
        
        // Server
        if self.server == nil {
            self.server = server
        }
        
        // Username
        if self.username != username {
            self.username = username
        }
        
        // User status
        if self.status != userStatus.rawValue {
            self.status = userStatus.rawValue
        }

        // When the name is not provided, build name from the path
        let login = username.isEmpty ? pwgUserStatus.guest.rawValue : username
        let newName = name.isEmpty ? login + " @ " + server.path : name
        if self.name != newName {
            self.name = newName
        }
        
        // Last time the user used this account
        let lastUsedInterval = lastUsed.timeIntervalSinceReferenceDate
        if self.lastUsed != lastUsedInterval {
            self.lastUsed = lastUsedInterval
        }
    }
    
    func addUploadRightsToAlbum(withID ID: Int32) {
        var setOfIDs = Set(self.uploadRights.components(separatedBy: ",").compactMap({Int32($0)}))
        if setOfIDs.insert(ID) == (true, ID) {
            // ID added to set of album IDs
            if setOfIDs.isEmpty {
                self.uploadRights = ""
            } else {
                self.uploadRights = String(setOfIDs.map({"\($0),"}).reduce("", +).dropLast(1))
            }
        }
    }
    
    func removeUploadRightsToAlbum(withID ID: Int32) {
        var setOfIDs = Set(self.uploadRights.components(separatedBy: ",").compactMap({Int32($0)}))
        if setOfIDs.remove(ID) == ID {
            // ID removed from the set of album IDs
            if setOfIDs.isEmpty {
                self.uploadRights = ""
            } else {
                self.uploadRights = String(setOfIDs.map({"\($0),"}).reduce("", +).dropLast(1))
            }
        }
    }
}


extension User {
    public var role: pwgUserStatus {
        return pwgUserStatus(rawValue: self.status) ?? .guest
    }
    
    public var hasAdminRights: Bool {
        return [.webmaster, .admin].contains(self.role)
    }
    
    public func hasUploadRights(forCatID categoryId: Int32) -> Bool {
        // Case of Community user?
        if self.hasAdminRights { return true }
        if self.role != .normal { return false }
        return self.uploadRights.components(separatedBy: ",").contains(String(categoryId))
    }
}
