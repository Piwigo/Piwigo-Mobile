//
//  UploadUtilitiesObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class UploadUtilitiesObjc: NSObject {
    // This class is temporary and used to add freshly uploaded images to memory.
    /// It will be removed with CategoriesData when all data will be stored in a CoreData database.
        
    // Add image uploaded to the Piwigo server
    @objc class func addImage(_ notification: Notification) {
        // Prepare image for cache
        let imageData = PiwigoImageData()
        imageData.imageId = notification.userInfo?["imageId"] as? Int ?? NSNotFound
        imageData.categoryIds = [(notification.userInfo?["categoryId"] as? Int ?? 0) as NSNumber]
        
        imageData.imageTitle = notification.userInfo?["imageTitle"] as? String ?? ""
        imageData.author = notification.userInfo?["author"] as? String ?? ""
        imageData.privacyLevel = kPiwigoPrivacyObjc(rawValue: notification.userInfo?["privacyLevel"] as? Int32 ?? Int32(kPiwigoPrivacy.unknown.rawValue))
        imageData.comment = notification.userInfo?["comment"] as? String ?? ""
        imageData.visits = notification.userInfo?["visits"] as? Int ?? 0
        imageData.ratingScore = notification.userInfo?["ratingScore"] as? Float ?? 0.0

        // Switch to old cache data format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var tagList = [PiwigoTagData]()
        let tags = notification.userInfo?["tags"] as? [TagProperties] ?? []
        tags.forEach { (tag) in
            let newTag = PiwigoTagData()
            newTag.tagId = Int(tag.id!)
            newTag.tagName = tag.name
            newTag.lastModified = dateFormatter.date(from: tag.lastmodified ?? "")
            newTag.numberOfImagesUnderTag = tag.counter ?? 0
            tagList.append(newTag)
        }
        imageData.tags = tagList

        imageData.fileName = notification.userInfo?["fileName"] as? String ?? "image.jpg"
        imageData.fileSize = notification.userInfo?["fileSize"] as? Int ?? NSNotFound    // Will trigger pwg.images.getInfo
        imageData.isVideo = notification.userInfo?["isVideo"] as? Bool ?? false
        imageData.datePosted = notification.userInfo?["datePosted"] as? Date ?? Date()
        imageData.dateCreated = notification.userInfo?["dateCreated"] as? Date ?? Date()
        imageData.md5checksum = notification.userInfo?["md5checksum"] as? String ?? ""

        imageData.fullResPath = notification.userInfo?["fullResPath"] as? String ?? ""
        imageData.fullResWidth = notification.userInfo?["fullResWidth"] as? Int ?? 1
        imageData.fullResHeight = notification.userInfo?["fullResHeight"] as? Int ?? 1
        imageData.squarePath = notification.userInfo?["squarePath"] as? String ?? ""
        imageData.squareWidth = notification.userInfo?["squareWidth"] as? Int ?? 1
        imageData.squareHeight = notification.userInfo?["squareHeight"] as? Int ?? 1
        imageData.thumbPath = notification.userInfo?["thumbPath"] as? String ?? ""
        imageData.thumbWidth = notification.userInfo?["thumbWidth"] as? Int ?? 1
        imageData.thumbHeight = notification.userInfo?["thumbHeight"] as? Int ?? 1
        imageData.mediumPath = notification.userInfo?["mediumPath"] as? String ?? ""
        imageData.mediumWidth = notification.userInfo?["mediumWidth"] as? Int ?? 1
        imageData.mediumHeight = notification.userInfo?["mediumHeight"] as? Int ?? 1
        imageData.xxSmallPath = notification.userInfo?["xxSmallPath"] as? String ?? ""
        imageData.xxSmallWidth = notification.userInfo?["xxSmallWidth"] as? Int ?? 1
        imageData.xxSmallHeight = notification.userInfo?["xxSmallHeight"] as? Int ?? 1
        imageData.xSmallPath = notification.userInfo?["xSmallPath"] as? String ?? ""
        imageData.xSmallWidth = notification.userInfo?["xSmallWidth"] as? Int ?? 1
        imageData.xSmallHeight = notification.userInfo?["xSmallHeight"] as? Int ?? 1
        imageData.smallPath = notification.userInfo?["smallPath"] as? String ?? ""
        imageData.smallWidth = notification.userInfo?["smallWidth"] as? Int ?? 1
        imageData.smallHeight = notification.userInfo?["smallHeight"] as? Int ?? 1
        imageData.largePath = notification.userInfo?["largePath"] as? String ?? ""
        imageData.largeWidth = notification.userInfo?["largeWidth"] as? Int ?? 1
        imageData.largeHeight = notification.userInfo?["largeHeight"] as? Int ?? 1
        imageData.xLargePath = notification.userInfo?["xLargePath"] as? String ?? ""
        imageData.xLargeWidth = notification.userInfo?["xLargeWidth"] as? Int ?? 1
        imageData.xLargeHeight = notification.userInfo?["xLargeHeight"] as? Int ?? 1
        imageData.xxLargePath = notification.userInfo?["xxLargePath"] as? String ?? ""
        imageData.xxLargeWidth = notification.userInfo?["xxLargeWidth"] as? Int ?? 1
        imageData.xxLargeHeight = notification.userInfo?["xxLargeHeight"] as? Int ?? 1
        
        // Add uploaded image to cache and update UI if needed
        DispatchQueue.main.async {
            CategoriesData.sharedInstance()?.addImage(imageData)
        }
    }
    
    @objc class func disableAutoUpload() {
        UploadManager.shared.backgroundQueue.async {
            UploadManager.shared.disableAutoUpload()
        }
    }
}
