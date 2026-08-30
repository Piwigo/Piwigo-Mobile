//
//  UserProperties.swift
//  PwgKit
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
    public var pwgID: Int16                         // Piwigo user ID
    public var login: String                        // Username or API public key
    public var username: String                     // User's account name
    public var name: String                         // User's name
    public var email: String                        // User's email
    public var status: String                       // See pwgUserStatus
    
    public var recentPeriod: Int16                  // Recent period in number of days
    public var registrationDate: TimeInterval       // Date of account creation
    public var lastUsed: TimeInterval               // Last time the account was accessed
    
    public var createAlbumRights: String?           // Allowed to create albums in album IDs
    public var uploadRights: String                 // Allowed to upload in album IDs
    public var downloadRights: Bool                 // Allowed to download
    
    public var URIstr: String                       // URI string representation
}


extension UserProperties
{
    public init(withStatus status: pwgUserStatus) {
        self.init(pwgID: 0, login: "", username: "", name: "", email: "",
                  status: status.rawValue, recentPeriod: 7,
                  registrationDate: Date.distantPast.timeIntervalSinceReferenceDate,
                  lastUsed: Date.distantPast.timeIntervalSinceReferenceDate,
                  createAlbumRights: nil, uploadRights: "", downloadRights: false,
                  URIstr: "")
    }
    
    public var role: pwgUserStatus {
        return pwgUserStatus(rawValue: self.status) ?? .guest
    }
    
    public var hasAdminRights: Bool {
        return [.webmaster, .admin].contains(self.role)
    }
    
    public func canManageFavorites() -> Bool {
        return !(self.role == .guest)
    }
    
    public func canDownloadImages() -> Bool {
        // Since Piwigo 14, pwg.categories.getImages method returns download_url if the user has download rights
        // For previous versions, we assumed that all only registered users have download rights
        // The download right is reset each time a batch of images is imported.
        let versionTooOld = ServerVars.shared.pwgVersion.compare("14.0", options: .numeric) == .orderedAscending
        if versionTooOld, self.role == .guest {
            return false
        }
        if versionTooOld == false, self.downloadRights == false {
            return false
        }
        return true
    }
    
    public var hasUploadRights: Bool {
        // Admin user?
        if self.hasAdminRights { return true }
        // Guest user?
        if self.role == .guest { return false }
        // Community user (.generic or .normal) ?
        return ServerVars.shared.usesCommunityPluginV29
    }
    
    public func hasUploadRights(forCatID categoryID: Int32) -> Bool {
        // Admin user?
        if self.hasAdminRights { return true }
        // Guest user?
        if self.role == .guest { return false }
        // Community user (.generic or .normal) ?
        if ServerVars.shared.usesCommunityPluginV29 == false { return false }
        switch categoryID {
        case .zero:
            return false
        case 1...Int32.max:
            return self.uploadRights.components(separatedBy: ",").contains(String(categoryID))
        default:
            return false
        }
    }
    
    public func hasAlbumCreationRights(inCatID categoryID: Int32) -> Bool {
        // Admin user?
        if self.hasAdminRights { return true }
        // Guest user?
        if self.role == .guest { return false }
        // Community user (.generic or .normal) ?
        if ServerVars.shared.usesCommunityPluginV29 == false { return false }
        switch categoryID {
        case 0...Int32.max:
            guard let createAlbumRights = self.createAlbumRights else { return false }
            return createAlbumRights.components(separatedBy: ",").contains(String(categoryID))
        default:
            return false
        }
    }

    public func hasEditRights(forImagesAddedToAlbum categoryID: Int32, byUserWithIDs addedByIDs: Set<Int16>) -> Bool {
        // Admin user?
        if self.hasAdminRights { return true }
        // Guest user?
        if self.role == .guest { return false }
        // Community user (.generic or .normal) ?
        if ServerVars.shared.usesCommunityPluginV29 == false { return false }
        switch categoryID {
        case Int32.min ... -1:  // Smart albums
            return self.editRights(forImagesAddedToAlbum: categoryID, byUserWithIDs: addedByIDs)
        case .zero:             // Root album
            return false
        case 1 ... Int32.max:   // Regular albums
            return self.editRights(forImagesAddedToAlbum: categoryID, byUserWithIDs: addedByIDs)
        default:
            return false
        }
    }
    
    fileprivate func editRights(forImagesAddedToAlbum categoryID: Int32, byUserWithIDs addedByIDs: Set<Int16>) -> Bool {
        // First check that the user has upload rights to that album
        guard self.uploadRights.components(separatedBy: ",").contains(String(categoryID))
        else { return false }
        
        // Because the 'addedBy' attribute of an image is known only after retrieving complete data,
        // and because the user ID is known only after a first upload (if the cache is not cleared),
        // we allow Community users to try to edit image properties or copy/move/delete images
        // when we do not have enough information.
        if addedByIDs.isEmpty || self.pwgID == 0 { return true }
        // Images added by current user?
        if addedByIDs == [self.pwgID] { return true }
        return false
    }
}
