//
//  User+CoreDataClass.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 28/08/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData
import PwgKit

/* User instances represent user accounts of a Piwigo server.
    - Instances are associated to a Server instance and differentiate with usernames.
    - Because album contents depend on user rights, each instance is associated to a series of dedicated albums.
    - Instances share images whose access is defined by album data.
    - Each instance contains upload requests only belonging to it.
 */
@objc(User)
public final nonisolated class User: NSManagedObject, Identifiable {
    
    /**
     Updates a User instance from UserProperties.
     */
    public func update(with userProperties: UserProperties,
                       onServer server: Server) throws {
        
        // Check user's status
        guard pwgUserStatus.allCases.contains(userProperties.role)
        else { throw PwgKitError.unknownUserStatus }
        if self.status != userProperties.status {
            self.status = userProperties.status
        }
        
        // Piwigo ID
        if userProperties.pwgID != Int16.min,
           userProperties.pwgID != self.pwgID {
            self.pwgID = userProperties.pwgID
        }
        
        // Login, i.e. username or API public key (empty for guest)
        if self.login != userProperties.login {
            self.login = userProperties.login
        }
        
        // Username
        if self.username != userProperties.username {
            self.username = userProperties.username
        }
        
        // When the name is not provided, build name from path
        let login = userProperties.username.isEmpty ? pwgUserStatus.guest.rawValue : username
        let newName = userProperties.name.isEmpty ? login + " @ " + server.path : userProperties.name
        if self.name != newName {
            self.name = newName
        }
        
        // Email
        if self.email != userProperties.email {
            self.email = userProperties.email
        }
        
        // Recent period
        if self.recentPeriod != userProperties.recentPeriod {
            self.recentPeriod = userProperties.recentPeriod
        }
        
        // Registration date
        if self.registrationDate != userProperties.registrationDate {
            self.registrationDate = userProperties.registrationDate
        }
        
        // Last time the user accessed this account
        if self.lastUsed < userProperties.lastUsed {
            self.lastUsed = userProperties.lastUsed
        }
        
        // IDs of albums in which the user can create sub-albums
        // Returned by community.session.getStatus
        if self.createAlbumRights != userProperties.createAlbumRights {
            self.createAlbumRights = userProperties.createAlbumRights
        }
        
        // IDs of albums in which the user can upload images
        // i.e. for which the Community user has 'admin' access
        if self.uploadRights != userProperties.uploadRights {
            self.uploadRights = userProperties.uploadRights
        }
        
        // User has download rights or not
        // Since Piwigo 14, pwg.categories.getImages method returns download_url if the user has download rights
        // For previous versions, we assumed that all only registered users have download rights
        // The download right is reset each time a batch of images is imported.
        if self.downloadRights != userProperties.downloadRights {
            self.downloadRights = userProperties.downloadRights
        }
        
        // Server to which the user account belongs to
        if let knownServer = self.server {
            if knownServer.lastUsed < userProperties.lastUsed {
                self.server?.lastUsed = userProperties.lastUsed
            }
        } else {
            self.server = server
        }
    }
        
    public func addUploadRightsToAlbum(withID ID: Int32) {
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
    public func getProperties() -> UserProperties {
        return UserProperties(
            pwgID: self.pwgID, login: self.login,
            username: self.username, name: self.name, email: self.email, status: self.status,
            recentPeriod: self.recentPeriod,
            registrationDate: self.registrationDate, lastUsed: self.lastUsed,
            createAlbumRights: self.createAlbumRights,
            uploadRights: self.uploadRights, downloadRights: self.downloadRights,
            URIstr: self.objectID.uriRepresentation().absoluteString)
    }
}
