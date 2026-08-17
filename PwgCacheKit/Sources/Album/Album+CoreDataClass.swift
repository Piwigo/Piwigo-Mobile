//
//  Album+CoreDataClass.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData
import PwgKit

/* Album instances represent albums of a Piwigo server.
    - Each instance is associated to a Server and a User because album contents depend on user rights.
    - Instances share images belonging to a server.
    - Smart albums are defined with pwgSmartAlbum and have Piwigo IDs <= 0.
 */
@objc(Album)
public final nonisolated class Album: NSManagedObject, Identifiable {
    /**
     Updates an Album instance with the values from a CategoryGetInfo struct.
     */
    public func update(with albumData: CategoryGetInfo, userURIstr: String) throws {
        
        // Update the album only if the ID and name properties have values.
        guard let newPwgId = albumData.id,
              let newName = albumData.name
        else {
            throw PwgKitError.missingAlbumData
        }
        if uuid.isEmpty {
            uuid = UUID().uuidString
        }
        if pwgID != newPwgId {
            pwgID = newPwgId
        }
        
        // Album name (required)
        let newNameUTF8 = newName.utf8mb4Encoded
        if name != newNameUTF8 {
            name = newNameUTF8
        }
        
        // Album status
        switch albumData.status {
        case pwgAlbumStatus.publicStatus.argument:
            if status != pwgAlbumStatus.publicStatus.rawValue {
                status = pwgAlbumStatus.publicStatus.rawValue
            }
        case pwgAlbumStatus.privateStatus.argument:
            if status != pwgAlbumStatus.privateStatus.rawValue {
                status = pwgAlbumStatus.privateStatus.rawValue
            }
        default:
            if status != pwgAlbumStatus.unknown.rawValue {
                status = pwgAlbumStatus.unknown.rawValue
            }
        }
        
        // Album description (required)
        let newCommentStr = albumData.comment?.utf8mb4Encoded ?? ""
        if commentStr != newCommentStr {
            commentStr = newCommentStr
        }
        let newCommentRaw = albumData.commentRaw?.utf8mb4Encoded ?? ""
        if commentRaw != newCommentRaw {
            commentRaw = newCommentRaw
        }
        let newComment = newCommentStr.attributedPlain
        if comment != newComment {
            comment = newComment
        }
        let newCommentHTML = newCommentStr.attributedHTML
        if newCommentHTML != commentHTML {
            commentHTML = newCommentHTML
        }
        
        // Album page URL
        /// - Store relative URLs to save space and because the URL might changed in future
        let newPageUrl = ImageGetInfo.encodedImageURL(albumData.pageUrl ?? "")
        if pageUrl != newPageUrl {
            pageUrl = newPageUrl
        }
        
        // Album rank (required)
        let newGlobalRank = albumData.globalRank ?? ""
        if globalRank != newGlobalRank {
            globalRank = newGlobalRank
        }
        
        // When upperCat i.e. parentId is null or not supplied, album at the root (required)
        let newUpperCat = Int32(albumData.upperCat ?? "") ?? 0
        if parentId != newUpperCat {
            parentId = newUpperCat
        }
        
        // Album parend album IDs (required)
        let newUpperCats = albumData.upperCats ?? ""
        if upperIds != newUpperCats {
            upperIds = newUpperCats
        }
        
        // Image sort option (required)
        let newImageSort = albumData.imageSort ?? ""
        if imageSort != newImageSort {
            imageSort = newImageSort
        }
        
        // Number of images and sub-albums
        let newNbImages = albumData.nbImages ?? Int64.zero
        if nbImages != newNbImages {
            nbImages = newNbImages
        }
        let newTotalNbImages = albumData.totalNbImages ?? Int64.zero
        if totalNbImages != newTotalNbImages {
            totalNbImages = newTotalNbImages
        }
        let newNbCategories = albumData.nbCategories ?? Int32.zero
        if nbSubAlbums != newNbCategories {
            nbSubAlbums = newNbCategories
        }
        
        // Album thumbnail
        /// - Store relative URLs to save space and because the URL might changed in future
        /// - Remove photo from cache if the path has changed
        let newThumbailId = Int64(albumData.thumbnailId ?? "") ?? Int64.zero
        if thumbnailId != newThumbailId {
            thumbnailId = newThumbailId
        }
        let newThumbnailUrl = ImageGetInfo.encodedImageURL(albumData.thumbnailUrl ?? "")
        if thumbnailUrl != newThumbnailUrl {
            thumbnailUrl = newThumbnailUrl
        }
        
        // When "date_last" is null or not supplied: date in distant past
        /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
        if let newTimeInterval = DateUtilities.timeInterval(from: albumData.dateLast) {
            if dateLast != newTimeInterval {
                dateLast = newTimeInterval
            }
        } else {
            dateLast = DateUtilities.unknownDateInterval
        }
        
        // This album belongs to the provided user
        if user == nil,
           let userURI = URL(string: userURIstr),
           let userID = self.managedObjectContext?.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI),
           let userInContext = self.managedObjectContext?.object(with: userID) as? User {
            user = userInContext
        }
        
        // Adopt the default counter starting value
        // the first time the abum is stored in persistent cache
        // (used to name files before upload)
        if currentCounter < 0 {
            currentCounter = UploadVars.shared.categoryCounterInit
        }
    }
    
    /**
     Updates a User instance from UserProperties.
     */
    public func update(with albumData: AlbumProperties) throws {
        
        // Album name (required)
        let newNameUTF8 = albumData.name.utf8mb4Encoded
        if name != newNameUTF8 {
            name = newNameUTF8
        }
                
        // Number of images and sub-albums
        let newNbImages = albumData.nbImages
        if nbImages != newNbImages {
            nbImages = newNbImages
        }
        let newTotalNbImages = albumData.totalNbImages
        if totalNbImages != newTotalNbImages {
            totalNbImages = newTotalNbImages
        }
        
        // Counter for renaming files before upload
        if currentCounter < albumData.currentCounter {
            currentCounter = albumData.currentCounter
        }
    }
}


extension Album
{
    public func getProperties() -> AlbumProperties {
        return AlbumProperties(
            pwgID: self.pwgID, name: self.name,
            status: pwgAlbumStatus(rawValue: self.status) ?? .unknown,
            /// The bridge is lossless: every attribute produced by String.attributedHTML
            /// belongs to a registered AttributeScope. Only unregistered keys would be dropped.
            comment: AttributedString(self.comment),
            commentHTML: AttributedString(self.commentHTML),
            pageUrl: self.pageUrl as? URL,
            query: self.query,
            
            upperIds: self.upperIds,
            
            nbImages: self.nbImages, totalNbImages: self.totalNbImages,
            images: (self.images ?? Set<Image>()).map { $0.pwgID },
            imageSort: self.imageSort,
            currentCounter: self.currentCounter,
            dateGetImages: self.dateGetImages,
            
            URIstr: self.objectID.uriRepresentation().absoluteString,
            userURIstr: self.user?.objectID.uriRepresentation().absoluteString ?? ""
        )
    }
}
