//
//  Album+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit

/* Album instances represent albums of a Piwigo server.
    - Each instance is associated to a Server and a User because album contents depend on user rights.
    - Instances share images belonging to a server.
    - Smart albums are defined with pwgSmartAlbum and have Piwigo IDs <= 0.
 */
@objc(Album)
public class Album: NSManagedObject {
    /**
     Updates an Album instance with the values from a CategoryData struct.
     */
    func update(with albumData: CategoryData, userObjectID: NSManagedObjectID) throws {
        
        // Update the album only if the Id and Name properties have values.
        guard let newPwgId = albumData.id,
              let newName = albumData.name else {
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
        let newThumbnailUrl = JSONManager.encodedImageURL(albumData.thumbnailUrl ?? "")
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
           let userInContext = self.managedObjectContext?.object(with: userObjectID) as? User {
            user = userInContext
        }
        
        // Adopt the default counter starting value
        // the first time the abum is stored in persistent cache
        // (used to name files before upload)
        if currentCounter < 0 {
            currentCounter = UploadVars.shared.categoryCounterInit
        }
    }
}
