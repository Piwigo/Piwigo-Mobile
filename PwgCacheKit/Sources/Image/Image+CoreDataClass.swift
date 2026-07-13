//
//  Image+CoreDataClass.swift
//  PwgCacheKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import os
import CoreData
import Foundation
import UIKit
import UniformTypeIdentifiers
import PwgKit

/* Image instances represent photos and videos of a Piwigo server.
    - Each instance belongs to a Server.
    - Image files are stored in cache, in a folder belonging to the appropriate server.
    - Image files are automatically deleted from the cache when deleting an instance.
 */
@objc(Image)
public final nonisolated class Image: NSManagedObject, Identifiable {
    
    // Logs Image updates
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.cacheKit", category: String(describing: Image.self))
    
    /**
     Updates an Image instance with the values from a ImageGetInfo struct.
     NB: A single tag is returned by pwg.categories.getImages!
     */
    public func update(with imageData: ImageGetInfo, sort: pwgImageSort, rank: Int64,
                       user: User, albums: Set<Album>) throws {
        
        // Update the image only if the Id has a value.
        guard let newPwgID = imageData.id else {
            throw PwgKitError.missingImageData
        }
        if uuid.isEmpty {
            uuid = UUID().uuidString
        }
        if pwgID != newPwgID {
            pwgID = newPwgID
        }
        
        // Image title (required)
        let newTitleStr = imageData.title?.utf8mb4Encoded ?? ""
        if titleStr != newTitleStr {
            titleStr = newTitleStr
        }
        let newTitle = newTitleStr.attributedPlain
        if newTitle != title {
            title = newTitle
        }
        
        // Image description (required)
        let newCommentStr = imageData.comment?.utf8mb4Encoded ?? ""
        if commentStr != newCommentStr {
            commentStr = newCommentStr
        }
        let newCommentRaw = imageData.commentRaw?.utf8mb4Encoded ?? ""
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
        
        // Image visits (returned by pwg.category.getImages)
        let newVisits = imageData.visits ?? Int32.zero
        if visits != newVisits {
            visits = newVisits
        }
        
        // Image rating score (returned by pwg.images.getInfo)
        // Should not be NaN because it can be used as a sorting criterion
        let newScore = Float(imageData.ratingScore ?? "") ?? -1.0
        if newScore != -1.0, ratingScore != newScore {
            ratingScore = newScore
        }
        
        // Image file size, name and MD5 checksum
        let newSize = 1024 * (imageData.fileSize ?? Int64.zero)
        if newSize != Int64.zero {
            // Remember when pwg.images.getInfos was called
            dateGetInfos = Date().timeIntervalSinceReferenceDate
            // Check if the value has changed
            if fileSize != newSize {
                fileSize = newSize
            }
        }
        
        let newMD5 = imageData.md5checksum ?? ""
        if newMD5.isEmpty == false, md5sum != newMD5 {
            md5sum = newMD5
            // Delete cache files to force a reload
            self.deleteCachedFiles()
        }
        let newFile = imageData.fileName?.utf8mb4Encoded ?? ""
        if newFile.isEmpty == false {
            if fileName != newFile {
                fileName = newFile
            }
            let fileExt = URL(fileURLWithPath: newFile).pathExtension.lowercased()
            if fileExt.isEmpty == false {
                if let uti = UTType(filenameExtension: fileExt) {
                    if uti.conforms(to: .movie) {
                        if fileType != pwgImageFileType.video.rawValue {
                            fileType = pwgImageFileType.video.rawValue
                        }
                    } else if uti.conforms(to: .pdf) {
                        if fileType != pwgImageFileType.pdf.rawValue {
                            fileType = pwgImageFileType.pdf.rawValue
                        }
                    } else {
                        if fileType != pwgImageFileType.image.rawValue {
                            fileType = pwgImageFileType.image.rawValue
                        }
                    }
                } else if fileType != pwgImageFileType.image.rawValue {
                    fileType = pwgImageFileType.image.rawValue
                }
            }
        }
        
        // Update date only if new date is after 00:00:00 UTC on 8 January 1900
        if let newPostedInterval = DateUtilities.timeInterval(from: imageData.datePosted) {
            if newPostedInterval != datePosted {
                datePosted = newPostedInterval
            }
        } else {
            datePosted = DateUtilities.unknownDateInterval
            Image.logger.notice("Could not update datePosted attribute of Image \(newPwgID, privacy: .public) from '\(imageData.datePosted ?? "nil", privacy: .public)'")
        }
        if let newCreatedInterval = DateUtilities.timeInterval(from: imageData.dateCreated) {
            if newCreatedInterval != dateCreated {
                dateCreated = newCreatedInterval
            }
        } else {
            dateCreated = DateUtilities.unknownDateInterval
            Image.logger.notice("Could not update dateCreated attribute of Image \(newPwgID, privacy: .public) from '\(imageData.dateCreated ?? "nil", privacy: .public)'")
        }
        
        // Author
        if let newAuthor = imageData.author {
            let newAuthorUTF8 = newAuthor.utf8mb4Encoded
            if author != newAuthorUTF8 {
                author = newAuthorUTF8
            }
        }
        
        // Privacy level
        let level = Int16(imageData.privacyLevel ?? "") ?? pwgPrivacy.unknown.rawValue
        let newPrivacy = (pwgPrivacy(rawValue: level) ?? .unknown).rawValue
        if newPrivacy != -1, privacyLevel != newPrivacy {
            privacyLevel = newPrivacy
        }
        
        // Add tags (Attention: pwg.categories.getImages returns only one tag)
        if imageData.title != nil {
            if let tags = imageData.tags, let serverTags = user.server?.tags {
                let tagIds = tags.map { $0.id?.int32Value }
                let imageTags = serverTags.filter({ tag in
                    tagIds.contains(where: { $0 == tag.tagId }) == true
                })
                let oldTags = self.tags?.compactMap{ $0.objectID }
                let newTags = imageTags.map { $0.objectID }
                if oldTags != newTags {
                    self.tags = imageTags
                }
            } else if self.tags?.isEmpty == false {
                self.tags = Set<Tag>()
            }
        }
        
        // Full resolution image
        let fullResUrl = ImageGetInfo.encodedImageURL(imageData.fullResPath ?? "")
        let newFull = Resolution(imageWidth: imageData.fullResWidth ?? 1,
                                 imageHeight: imageData.fullResHeight ?? 1,
                                 imageURL: NSURL(string: fullResUrl?.absoluteString ?? ""))
        if fullRes == nil || fullRes?.isEqual(newFull) == false {
            fullRes = newFull
            // Delete cached image files (image updated, was probably rotated)
            deleteCachedFiles()
        }
        
        // Derivatives
        let squareRes = imageData.derivatives.squareImage
        let squareUrl = ImageGetInfo.encodedImageURL(squareRes?.url ?? "")
        let newSquare = Resolution(imageWidth: squareRes?.width?.intValue ?? 1,
                                   imageHeight: squareRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: squareUrl?.absoluteString ?? ""))
        if sizes.square == nil || sizes.square?.isEqual(newSquare) == false {
            sizes.square = newSquare
        }
        
        let thumbRes = imageData.derivatives.thumbImage
        let thumbUrl = ImageGetInfo.encodedImageURL(thumbRes?.url ?? "")
        let newThumb = Resolution(imageWidth: thumbRes?.width?.intValue ?? 1,
                                  imageHeight: thumbRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: thumbUrl?.absoluteString ?? ""))
        if sizes.thumb == nil || sizes.thumb?.isEqual(newThumb) == false {
            sizes.thumb = newThumb
        }
        
        let mediumRes = imageData.derivatives.mediumImage
        let mediumUrl = ImageGetInfo.encodedImageURL(mediumRes?.url ?? "")
        let newMedium = Resolution(imageWidth: mediumRes?.width?.intValue ?? 1,
                                   imageHeight: mediumRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: mediumUrl?.absoluteString ?? ""))
        if sizes.medium == nil || sizes.medium?.isEqual(newMedium) == false {
            sizes.medium = newMedium
        }
        
        let smallRes = imageData.derivatives.smallImage
        let smallUrl = ImageGetInfo.encodedImageURL(smallRes?.url ?? "")
        let newSmall = Resolution(imageWidth: smallRes?.width?.intValue ?? 1,
                                  imageHeight: smallRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: smallUrl?.absoluteString ?? ""))
        if sizes.small == nil || sizes.small?.isEqual(newSmall) == false {
            sizes.small = newSmall
        }
        
        let xsmallRes = imageData.derivatives.xSmallImage
        let xsmallUrl = ImageGetInfo.encodedImageURL(xsmallRes?.url ?? "")
        let newXsmall = Resolution(imageWidth: xsmallRes?.width?.intValue ?? 1,
                                   imageHeight: xsmallRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xsmallUrl?.absoluteString ?? ""))
        if sizes.xsmall == nil || sizes.xsmall?.isEqual(newXsmall) == false {
            sizes.xsmall = newXsmall
        }
        
        let xxsmallRes = imageData.derivatives.xxSmallImage
        let xxsmallUrl = ImageGetInfo.encodedImageURL(xxsmallRes?.url ?? "")
        let newXxsmall = Resolution(imageWidth: xxsmallRes?.width?.intValue ?? 1,
                                    imageHeight: xxsmallRes?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxsmallUrl?.absoluteString ?? ""))
        if sizes.xxsmall == nil || sizes.xxsmall?.isEqual(newXxsmall) == false {
            sizes.xxsmall = newXxsmall
        }
        
        let largeRes = imageData.derivatives.largeImage
        let largeUrl = ImageGetInfo.encodedImageURL(largeRes?.url ?? "")
        let newLarge = Resolution(imageWidth: largeRes?.width?.intValue ?? 1,
                                  imageHeight: largeRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: largeUrl?.absoluteString ?? ""))
        if sizes.large == nil || sizes.large?.isEqual(newLarge) == false {
            sizes.large = newLarge
        }
        
        let xlargeRes = imageData.derivatives.xLargeImage
        let xlargeUrl = ImageGetInfo.encodedImageURL(xlargeRes?.url ?? "")
        let newXlarge = Resolution(imageWidth: xlargeRes?.width?.intValue ?? 1,
                                   imageHeight: xlargeRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xlargeUrl?.absoluteString ?? ""))
        if sizes.xlarge == nil || sizes.xlarge?.isEqual(newXlarge) == false {
            sizes.xlarge = newXlarge
        }
        
        let xxlargeRes = imageData.derivatives.xxLargeImage
        let xxlargeUrl = ImageGetInfo.encodedImageURL(xxlargeRes?.url ?? "")
        let newXxlarge = Resolution(imageWidth: xxlargeRes?.width?.intValue ?? 1,
                                    imageHeight: xxlargeRes?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxlargeUrl?.absoluteString ?? ""))
        if sizes.xxlarge == nil || sizes.xxlarge?.isEqual(newXxlarge) == false {
            sizes.xxlarge = newXxlarge
        }
        
        let xxxlargeRes = imageData.derivatives.xxxLargeImage
        let xxxlargeUrl = ImageGetInfo.encodedImageURL(xxxlargeRes?.url ?? "")
        let newXxxlarge = Resolution(imageWidth: xxxlargeRes?.width?.intValue ?? 1,
                                     imageHeight: xxxlargeRes?.height?.intValue ?? 1,
                                     imageURL: NSURL(string: xxxlargeUrl?.absoluteString ?? ""))
        if sizes.xxxlarge == nil || sizes.xxxlarge?.isEqual(newXxxlarge) == false {
            sizes.xxxlarge = newXxxlarge
        }
        
        let xxxxlargeRes = imageData.derivatives.xxxxLargeImage
        let xxxxlargeUrl = ImageGetInfo.encodedImageURL(xxxxlargeRes?.url ?? "")
        let newXxxxlarge = Resolution(imageWidth: xxxxlargeRes?.width?.intValue ?? 1,
                                      imageHeight: xxxxlargeRes?.height?.intValue ?? 1,
                                      imageURL: NSURL(string: xxxxlargeUrl?.absoluteString ?? ""))
        if sizes.xxxxlarge == nil || sizes.xxxxlarge?.isEqual(newXxxxlarge) == false {
            sizes.xxxxlarge = newXxxxlarge
        }
        
        // Location
        let latitude = imageData.latitude?.doubleValue ?? 0.0
        if latitude != 0, self.latitude != latitude {
            self.latitude = latitude
        }
        let longitude = imageData.longitude?.doubleValue ?? 0.0
        if longitude != 0, self.longitude != longitude {
            self.longitude = longitude
        }
        
        // Download URL not nil and modified?
        let newDownloadUrl = ImageGetInfo.encodedImageURL(imageData.downloadUrl ?? "")
        if newDownloadUrl != nil, downloadUrl != newDownloadUrl {
            downloadUrl = newDownloadUrl
        }
        
        // Rank of image in album
        switch sort {
        case .rankAscending:
            if rank != Int64.min, rankManual != rank {
                rankManual = rank
            }
        case .random:
            if rank != Int64.min, rankRandom != rank {
                rankRandom = rank
            }
        default:
            break
        }
        
        // This image of the current server is accessible to the user
        if server == nil {
            server = user.server
        }
        if users == nil || users?.contains(where: { $0.objectID == user.objectID }) == false,
           let userInContext = self.managedObjectContext?.object(with: user.objectID) as? User {
            addToUsers(userInContext)
        }
        
        // Categories in which this image belongs to
        let albumIds = Set(self.albums?.compactMap({$0.objectID}) ?? [])
        let newAlbumIds = Set(albums.compactMap({$0.objectID}))
        if albumIds.isSuperset(of: newAlbumIds) == false {
            let newAlbums = Set(newAlbumIds.compactMap({self.managedObjectContext?.object(with: $0) as? Album}))
            addToAlbums(newAlbums)
        }
    }
    
    // Delete image files in cache before deleting object
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        
        self.deleteCachedFiles()
    }
    
    public func deleteCachedFiles() {
        // Delete cached image files in background queue
        let ID = String(self.pwgID)
        let IDopt = ID + optimisedImageNameExtension
        guard let serverUUID = self.server?.uuid else { return }
        let fm = FileManager.default
        let cacheUrl = DataDirectories.cacheDirectory
            .appendingPathComponent(serverUUID)
        
        // Loop over image sizes
        pwgImageSize.allCases.forEach { size in
            // Delete files
            let dirURL = cacheUrl.appendingPathComponent(size.path)
            do {
                try fm.removeItem(at: dirURL.appendingPathComponent(ID))
                try fm.removeItem(at: dirURL.appendingPathComponent(IDopt))
                //                debugPrint("••> \(size.name) image: \(self.pwgID) removed from cache.")
            } catch {
                //                debugPrint("••> \(size.name) image: \(error.localizedDescription)")
            }
        }
    }

    public func cacheURL(ofSize size: pwgImageSize) -> URL? {
        // Retrieve server ID
        let serverID = self.server?.uuid ?? ""
        if serverID.isEmpty { return nil }
        
        // Return the URL of the thumbnail file
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        return cacheDir.appendingPathComponent(size.path)
            .appendingPathComponent(String(self.pwgID))
    }
    
    public func cachedThumbnail(ofSize size: pwgImageSize) -> UIImage? {
        autoreleasepool {
            guard let fileURL = self.cacheURL(ofSize: size),
                  let image = UIImage(contentsOfFile: fileURL.path)
            else { return nil }
            return image
        }
    }

    // MARK: - Rotates Thumbnails
    public func rotateThumbnails(by angle: CGFloat) {
        // Initialisation
        guard let serverID = self.server?.uuid else { return }
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        let fm = FileManager.default
        
        // Loop over all sizes
        autoreleasepool {
            pwgImageSize.allCases.forEach { size in
                // Determine URL of image in cache
                let fileURL = cacheDir.appendingPathComponent(size.path)
                    .appendingPathComponent(String(self.pwgID))
                
                // Rotate thumbnail if any
                if let image = UIImage(contentsOfFile: fileURL.path),
                   let rotatedImage = image.rotated(by: -angle),
                   let data = rotatedImage.jpegData(compressionQuality: 1.0) as? NSData
                {
                    let filePath = fileURL.path
                    try? fm.removeItem(atPath: filePath)
                    do {
                        try data.write(toFile: filePath, options: .atomic)
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
                
                // Swap dimensions
                switch size {
                case .square:
                    self.sizes.square?.dimensionsSwaped()
                case .thumb:
                    self.sizes.thumb?.dimensionsSwaped()
                case .xxSmall:
                    self.sizes.xxsmall?.dimensionsSwaped()
                case .xSmall:
                    self.sizes.xsmall?.dimensionsSwaped()
                case .small:
                    self.sizes.small?.dimensionsSwaped()
                case .medium:
                    self.sizes.medium?.dimensionsSwaped()
                case .large:
                    self.sizes.large?.dimensionsSwaped()
                case .xLarge:
                    self.sizes.xlarge?.dimensionsSwaped()
                case .xxLarge:
                    self.sizes.xxlarge?.dimensionsSwaped()
                case .xxxLarge:
                    self.sizes.xxxlarge?.dimensionsSwaped()
                case .xxxxLarge:
                    self.sizes.xxxxlarge?.dimensionsSwaped()
                case .fullRes:
                    self.fullRes?.dimensionsSwaped()
                }
                
                // Rotate optimised image if any
                let filePath = fileURL.path + optimisedImageNameExtension
                if let image = UIImage(contentsOfFile: filePath),
                   let rotatedImage = image.rotated(by: -angle) {
                    rotatedImage.saveInOptimumFormat(atPath: filePath)
                }
                
                // The file size and MD5 checksum are unchanged.
            }
        }
    }
}


//extension Image
//{
//    func getProperties() -> ImageProperties
//    {
//        return ImageProperties(
//            pwgID: self.pwgID,
//            albumIDs: (self.albums ?? Set<Album>()).compactMap({ $0.pwgID })
//        )
//    }
//}
