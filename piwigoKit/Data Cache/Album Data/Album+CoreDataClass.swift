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

public class Album: NSManagedObject {
    /**
     Updates an Album instance with the values from a CategoryData struct.
     */
    func update(with albumData: CategoryData, user: User) throws {
        
        // Update the album only if the Id and Name properties have values.
        guard let newPwgId = albumData.id,
              let newName = albumData.name else {
                throw AlbumError.missingData
        }
        if uuid.isEmpty {
            uuid = UUID().uuidString
        }
        if pwgID != newPwgId {
            pwgID = newPwgId
        }
        let newNameUtf8mb4 = NetworkUtilities.utf8mb4String(from: newName)
        if name != newNameUtf8mb4 {
            name = newNameUtf8mb4
        }

        // Album description and rank
        let description = NetworkUtilities.utf8mb4String(from: albumData.comment ?? "")
                                          .htmlToAttributedString
        if comment.string != description.string {
            comment = description
        }
        let newGlobalRank = albumData.globalRank ?? ""
        if globalRank != newGlobalRank {
            globalRank = newGlobalRank
        }

        // When upperCat is null or not supplied: album at the root
        let newUpperCat = Int32(albumData.upperCat ?? "") ?? 0
        if parentId != newUpperCat {
            parentId = newUpperCat
        }
        let newUpperCats = albumData.upperCats ?? ""
        if upperIds != newUpperCats {
            upperIds = newUpperCats
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
        /// - Remove photo from cache if the path changed
        var thumbnailHasChanged = false
        let newThumbailId = Int64(albumData.thumbnailId ?? "") ?? Int64.max
        if thumbnailId != newThumbailId {
            thumbnailId = newThumbailId
            thumbnailHasChanged = true
        }
        let newThumbnailUrl = NetworkUtilities.encodedImageURL(albumData.thumbnailUrl ?? "")
        if thumbnailUrl != newThumbnailUrl {
            thumbnailUrl = newThumbnailUrl
            thumbnailHasChanged = true
        }
        if thumbnailHasChanged, let serverID = user.server?.uuid {
            let cacheDir = DataController.cacheDirectory.appendingPathComponent(serverID)
            for size in pwgImageSize.allCases {
                let fileUrl = cacheDir.appendingPathComponent(size.path).appendingPathComponent(uuid)
                try? FileManager.default.removeItem(at: fileUrl)
            }
        }

        // When "date_last" is null or not supplied: date in distant past
        /// - 'date_last' is the maximum 'date_available' of the images associated to an album.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let newDateLast = dateFormatter.date(from: albumData.dateLast ?? "") ?? .distantPast
        if dateLast != newDateLast {
            dateLast = newDateLast
        }

        // This album of the current server is accessible to the user
        if server == nil {
            server = user.server
        }
        if users == nil || users?.contains(where: { $0.objectID == user.objectID }) == false {
            addToUsers(user)
        }
    }
}
