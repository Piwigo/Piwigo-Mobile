//
//  Image+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import os
import CoreData
import Foundation
import MobileCoreServices

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers        // Requires iOS 14
#endif

/* Image instances represent photos and videos of a Piwigo server.
    - Each instance belongs to a Server.
    - Image files are stored in cache, in a folder belonging to the appropriate server.
    - Image files are automatically deleted from the cache when deleting an instance.
 */
@objc(Image)
public class Image: NSManagedObject {

    // Logs Image updates
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    @available(iOSApplicationExtension 14.0, *)
    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: String(describing: Image.self))

    /**
     Updates an Image instance with the values from a ImagesGetInfo struct.
     NB: A single tag is returned by pwg.categories.getImages!
     */
    func update(with imageData: ImagesGetInfo, sort: pwgImageSort, rank: Int64,
                user: User, albums: Set<Album>) throws {
        
        // Update the image only if the Id has a value.
        guard let newPwgID = imageData.id else {
            throw ImageError.missingData
        }
        if uuid.isEmpty {
            uuid = UUID().uuidString
        }
        if pwgID != newPwgID {
            pwgID = newPwgID
        }
        
        // Image title (required)
        let titleUTF8 = PwgSession.utf8mb4String(from: imageData.title)
        if titleStr != titleUTF8 {
            titleStr = titleUTF8
        }
        let titleAttrStr = titleUTF8.htmlToAttributedString
        if title != titleAttrStr {
            title = titleAttrStr
        }
        
        // Image description (required)
        let newCommentUTF8 = PwgSession.utf8mb4String(from: imageData.comment)
        let newCommentAttrStr = newCommentUTF8.htmlToAttributedString
        if comment != newCommentAttrStr {
            comment = newCommentAttrStr
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
        let newFile = PwgSession.utf8mb4String(from: imageData.fileName ?? "")
        if newFile.isEmpty == false {
            if fileName != newFile {
                fileName = newFile
            }
            let fileExt = URL(fileURLWithPath: newFile).pathExtension.lowercased()
            if fileExt.isEmpty == false {
                if #available(iOS 14.0, *) {
                    if let uti = UTType(filenameExtension: fileExt) {
                        let newIsVideo = uti.conforms(to: .movie)
                        if isVideo != newIsVideo {
                            isVideo = newIsVideo
                        }
                    }
                } else {
                    // Fallback to previous version
                    if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as NSString, nil)?.takeRetainedValue() {
                        let newIsVideo = UTTypeConformsTo(uti, kUTTypeMovie)
                        if isVideo != newIsVideo {
                            isVideo = newIsVideo
                        }
                    }
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
            if #available(iOSApplicationExtension 14.0, *) {
                Image.logger.notice("Could not update datePosted attribute of Image \(newPwgID, privacy: .public) from '\(imageData.datePosted ?? "nil", privacy: .public)'")
            }
        }
        if let newCreatedInterval = DateUtilities.timeInterval(from: imageData.dateCreated) {
            if newCreatedInterval != dateCreated {
                dateCreated = newCreatedInterval
            }
        } else {
            dateCreated = DateUtilities.unknownDateInterval
            if #available(iOSApplicationExtension 14.0, *) {
                Image.logger.notice("Could not update dateCreated attribute of Image \(newPwgID, privacy: .public) from '\(imageData.dateCreated ?? "nil", privacy: .public)'")
            }
        }
        
        // Author
        if let newAuthor = imageData.author {
           let newAuthorUTF8 = PwgSession.utf8mb4String(from: newAuthor)
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
        let fullResUrl = PwgSession.encodedImageURL(imageData.fullResPath ?? "")
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
        let squareUrl = PwgSession.encodedImageURL(squareRes?.url ?? "")
        let newSquare = Resolution(imageWidth: squareRes?.width?.intValue ?? 1,
                                   imageHeight: squareRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: squareUrl?.absoluteString ?? ""))
        if sizes.square == nil || sizes.square?.isEqual(newSquare) == false {
            sizes.square = newSquare
        }
        
        let thumbRes = imageData.derivatives.thumbImage
        let thumbUrl = PwgSession.encodedImageURL(thumbRes?.url ?? "")
        let newThumb = Resolution(imageWidth: thumbRes?.width?.intValue ?? 1,
                                  imageHeight: thumbRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: thumbUrl?.absoluteString ?? ""))
        if sizes.thumb == nil || sizes.thumb?.isEqual(newThumb) == false {
            sizes.thumb = newThumb
        }
        
        let mediumRes = imageData.derivatives.mediumImage
        let mediumUrl = PwgSession.encodedImageURL(mediumRes?.url ?? "")
        let newMedium = Resolution(imageWidth: mediumRes?.width?.intValue ?? 1,
                                   imageHeight: mediumRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: mediumUrl?.absoluteString ?? ""))
        if sizes.medium == nil || sizes.medium?.isEqual(newMedium) == false {
            sizes.medium = newMedium
        }
        
        let smallRes = imageData.derivatives.smallImage
        let smallUrl = PwgSession.encodedImageURL(smallRes?.url ?? "")
        let newSmall = Resolution(imageWidth: smallRes?.width?.intValue ?? 1,
                                  imageHeight: smallRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: smallUrl?.absoluteString ?? ""))
        if sizes.small == nil || sizes.small?.isEqual(newSmall) == false {
            sizes.small = newSmall
        }
        
        let xsmallRes = imageData.derivatives.xSmallImage
        let xsmallUrl = PwgSession.encodedImageURL(xsmallRes?.url ?? "")
        let newXsmall = Resolution(imageWidth: xsmallRes?.width?.intValue ?? 1,
                                   imageHeight: xsmallRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xsmallUrl?.absoluteString ?? ""))
        if sizes.xsmall == nil || sizes.xsmall?.isEqual(newXsmall) == false {
            sizes.xsmall = newXsmall
        }
        
        let xxsmallRes = imageData.derivatives.xxSmallImage
        let xxsmallUrl = PwgSession.encodedImageURL(xxsmallRes?.url ?? "")
        let newXxsmall = Resolution(imageWidth: xxsmallRes?.width?.intValue ?? 1,
                                    imageHeight: xxsmallRes?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxsmallUrl?.absoluteString ?? ""))
        if sizes.xxsmall == nil || sizes.xxsmall?.isEqual(newXxsmall) == false {
            sizes.xxsmall = newXxsmall
        }
        
        let largeRes = imageData.derivatives.largeImage
        let largeUrl = PwgSession.encodedImageURL(largeRes?.url ?? "")
        let newLarge = Resolution(imageWidth: largeRes?.width?.intValue ?? 1,
                                  imageHeight: largeRes?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: largeUrl?.absoluteString ?? ""))
        if sizes.large == nil || sizes.large?.isEqual(newLarge) == false {
            sizes.large = newLarge
        }
        
        let xlargeRes = imageData.derivatives.xLargeImage
        let xlargeUrl = PwgSession.encodedImageURL(xlargeRes?.url ?? "")
        let newXlarge = Resolution(imageWidth: xlargeRes?.width?.intValue ?? 1,
                                   imageHeight: xlargeRes?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xlargeUrl?.absoluteString ?? ""))
        if sizes.xlarge == nil || sizes.xlarge?.isEqual(newXlarge) == false {
            sizes.xlarge = newXlarge
        }
        
        let xxlargeRes = imageData.derivatives.xxLargeImage
        let xxlargeUrl = PwgSession.encodedImageURL(xxlargeRes?.url ?? "")
        let newXxlarge = Resolution(imageWidth: xxlargeRes?.width?.intValue ?? 1,
                                    imageHeight: xxlargeRes?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxlargeUrl?.absoluteString ?? ""))
        if sizes.xxlarge == nil || sizes.xxlarge?.isEqual(newXxlarge) == false {
            sizes.xxlarge = newXxlarge
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
        let newDownloadUrl = PwgSession.encodedImageURL(imageData.downloadUrl ?? "")
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
    
    /**
        Delete image files in cache before deleting object
     */
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        
        self.deleteCachedFiles()
    }
    
    public func deleteCachedFiles() {
        // Delete cached image files in background queue
        let ID = String(self.pwgID)
        let IDopt = ID + CacheVars.shared.optImage
        guard let serverUUID = self.server?.uuid else { return }
        let fm = FileManager.default
        let cacheUrl = DataDirectories.shared.cacheDirectory
            .appendingPathComponent(serverUUID)

        // Loop over image sizes
        pwgImageSize.allCases.forEach { size in
            // Delete files
            let dirURL = cacheUrl.appendingPathComponent(size.path)
            do {
                try fm.removeItem(at: dirURL.appendingPathComponent(ID))
                try fm.removeItem(at: dirURL.appendingPathComponent(IDopt))
                debugPrint("••> \(size.name) image: \(self.pwgID) removed from cache.")
            } catch {
                debugPrint("••> \(size.name) image: \(error.localizedDescription)")
            }
        }
    }
}
