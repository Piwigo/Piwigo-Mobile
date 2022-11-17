//
//  Image+CoreDataClass.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 10/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//
//

import CoreData
import Foundation
import MobileCoreServices

public class Image: NSManagedObject {
    /**
     Updates an Image instance with the values from a ImagesGetInfo struct.
     */
    func update(with imageData: ImagesGetInfo, user: User, albums: Set<Album>) throws {

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
        
        // Image title and description
        let imageTitle = NetworkUtilities.utf8mb4String(from: imageData.title ?? "").htmlToAttributedString
        if title.string != imageTitle.string {
            title = imageTitle
        }
        let description = NetworkUtilities.utf8mb4String(from: imageData.comment ?? "").htmlToAttributedString
        if comment.string != description.string {
            comment = description
        }
        
        // Image visits and rate
        let newVisits = imageData.visits ?? Int32.zero
        if visits != newVisits {
            visits = newVisits
        }
        let newScore = Float(imageData.ratingScore ?? "") ?? Float.zero
        if ratingScore != newScore {
            ratingScore = newScore
        }
        
        // Image file size, name and MD5 checksum
        let newSize = imageData.fileSize ?? Int64.zero
        if fileSize != newSize {
            fileSize = newSize
        }
        let newMD5 = imageData.md5checksum ?? ""
        if md5sum != newMD5 {
            md5sum = newMD5
        }
        let newFile = NetworkUtilities.utf8mb4String(from: imageData.fileName ?? "NoName.jpg")
        if fileName != newFile {
            fileName = newFile
        }
        let fileExt = URL(fileURLWithPath: fileName).pathExtension as NSString
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt, nil)?.takeRetainedValue() {
            let newIsVideo = UTTypeConformsTo(uti, kUTTypeMovie)
            if isVideo != newIsVideo {
                isVideo = newIsVideo
            }
        }
        
        // Image dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let newPosted = dateFormatter.date(from: imageData.datePosted ?? "") ?? Date()
        if datePosted != newPosted {
            datePosted = newPosted
        }
        let newCreated = dateFormatter.date(from: imageData.dateCreated ?? "") ?? datePosted
        if dateCreated != newCreated {
            dateCreated = newCreated
        }
        
        // Author
        let newAuthor = NetworkUtilities.utf8mb4String(from: imageData.author ?? "NSNotFound")
        if author != newAuthor {
            author = newAuthor
        }
        
        // Privacy level
        let level = Int16(imageData.privacyLevel ?? "") ?? kPiwigoPrivacy.unknown.rawValue
        let newPrivacy = (kPiwigoPrivacy(rawValue: level) ?? .unknown).rawValue
        if privacyLevel != newPrivacy {
            privacyLevel = newPrivacy
        }
        
        // Add tags
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

        // Full resolution image
        let fullResUrl = NetworkUtilities.encodedImageURL(imageData.fullResPath ?? "")
        let newFull = Resolution(imageWidth: imageData.fullResWidth ?? 1,
                                 imageHeight: imageData.fullResHeight ?? 1,
                                 imagePath: fullResUrl?.absoluteString ?? "",
                                 imageID: uuid)
        if fullRes == nil || fullRes?.isEqual(newFull) == false {
            fullRes = newFull
        }

        // Derivatives
        let square = imageData.derivatives.squareImage
        let squareUrl = NetworkUtilities.encodedImageURL(square?.url ?? "")
        let newSquare = Resolution(imageWidth: square?.width?.intValue ?? 1,
                                   imageHeight: square?.height?.intValue ?? 1,
                                   imagePath: squareUrl?.absoluteString ?? "",
                                   imageID: squareRes?.uuid)
        if squareRes == nil || squareRes?.isEqual(newSquare) == false {
            squareRes = newSquare
        }
        
        let thumb = imageData.derivatives.thumbImage
        let thumbUrl = NetworkUtilities.encodedImageURL(thumb?.url ?? "")
        let newThumb = Resolution(imageWidth: thumb?.width?.intValue ?? 1,
                                  imageHeight: thumb?.height?.intValue ?? 1,
                                  imagePath: thumbUrl?.absoluteString ?? "",
                                  imageID: thumbRes?.uuid)
        if thumbRes == nil || thumbRes?.isEqual(newThumb) == false {
            thumbRes = newThumb
        }
        
        let medium = imageData.derivatives.mediumImage
        let mediumUrl = NetworkUtilities.encodedImageURL(medium?.url ?? "")
        let newMedium = Resolution(imageWidth: medium?.width?.intValue ?? 1,
                                   imageHeight: medium?.height?.intValue ?? 1,
                                   imagePath: mediumUrl?.absoluteString ?? "",
                                   imageID: mediumRes?.uuid)
        if mediumRes == nil || mediumRes?.isEqual(newMedium) == false {
            mediumRes = newMedium
        }
        
        let small = imageData.derivatives.smallImage
        let smallUrl = NetworkUtilities.encodedImageURL(small?.url ?? "")
        let newSmall = Resolution(imageWidth: small?.width?.intValue ?? 1,
                                  imageHeight: small?.height?.intValue ?? 1,
                                  imagePath: smallUrl?.absoluteString ?? "",
                                  imageID: smallRes?.uuid)
        if smallRes == nil || smallRes?.isEqual(newSmall) == false {
            smallRes = newSmall
        }
        
        let xsmall = imageData.derivatives.xSmallImage
        let xsmallUrl = NetworkUtilities.encodedImageURL(xsmall?.url ?? "")
        let newXsmall = Resolution(imageWidth: xsmall?.width?.intValue ?? 1,
                                   imageHeight: xsmall?.height?.intValue ?? 1,
                                   imagePath: xsmallUrl?.absoluteString ?? "",
                                   imageID: xsmallRes?.uuid)
        if xsmallRes == nil || xsmallRes?.isEqual(newXsmall) == false {
            xsmallRes = newXsmall
        }
        
        let xxsmall = imageData.derivatives.xxSmallImage
        let xxsmallUrl = NetworkUtilities.encodedImageURL(xxsmall?.url ?? "")
        let newXxsmall = Resolution(imageWidth: xxsmall?.width?.intValue ?? 1,
                                    imageHeight: xxsmall?.height?.intValue ?? 1,
                                    imagePath: xxsmallUrl?.absoluteString ?? "",
                                    imageID: xxsmallRes?.uuid)
        if xxsmallRes == nil || xxsmallRes?.isEqual(newXxsmall) == false {
            xxsmallRes = newXxsmall
        }
        
        let large = imageData.derivatives.largeImage
        let largeUrl = NetworkUtilities.encodedImageURL(large?.url ?? "")
        let newLarge = Resolution(imageWidth: large?.width?.intValue ?? 1,
                                  imageHeight: large?.height?.intValue ?? 1,
                                  imagePath: largeUrl?.absoluteString ?? "",
                                  imageID: largeRes?.uuid)
        if largeRes == nil || largeRes?.isEqual(newLarge) == false {
            largeRes = newLarge
        }
        
        let xlarge = imageData.derivatives.xLargeImage
        let xlargeUrl = NetworkUtilities.encodedImageURL(xlarge?.url ?? "")
        let newXlarge = Resolution(imageWidth: xlarge?.width?.intValue ?? 1,
                                   imageHeight: xlarge?.height?.intValue ?? 1,
                                   imagePath: xlargeUrl?.absoluteString ?? "",
                                   imageID: xlargeRes?.uuid)
        if xlargeRes == nil || xlargeRes?.isEqual(newXlarge) == false {
            xlargeRes = newXlarge
        }
        
        let xxlarge = imageData.derivatives.xxLargeImage
        let xxlargeUrl = NetworkUtilities.encodedImageURL(xxlarge?.url ?? "")
        let newXxlarge = Resolution(imageWidth: xxlarge?.width?.intValue ?? 1,
                                    imageHeight: xxlarge?.height?.intValue ?? 1,
                                    imagePath: xxlargeUrl?.absoluteString ?? "",
                                    imageID: xxlargeRes?.uuid)
        if xxlargeRes == nil || xxlargeRes?.isEqual(newXxlarge) == false {
            xxlargeRes = newXxlarge
        }
        
        // This image of the current server is accessible to the user
        if server == nil {
            server = user.server
        }
        if users == nil ||
           users?.contains(where: { $0.objectID == user.objectID }) == false {
            addToUsers(user)
        }

        // Categories in which this image belongs to
        let albumIds = Set(self.albums?.compactMap({$0.objectID}) ?? [])
        let newAlbumIds = Set(albums.compactMap({$0.objectID}))
        if albumIds.isSuperset(of: newAlbumIds) == false {
            addToAlbums(albums)
        }
    }
    
    /**
        Delete image files in cache before deleting object
     */
    public override func prepareForDeletion() {
        super.prepareForDeletion()
        
        // Delete cached image files in background queue
        guard let serverUUID = self.server?.uuid else { return }
        let fm = FileManager.default
        let cacheUrl = DataController.cacheDirectory.appendingPathComponent(serverUUID)
        print("••> Image \(self.uuid) deleted from cache.")

        // Square resolution
        var fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.square.path)
                              .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> square resolution: \(error.localizedDescription)")
        }
        
        // Thumbnail resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.thumb.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> thumbnail resolution: \(error.localizedDescription)")
        }
        
        // XXSmall resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xxSmall.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> xxSmall resolution: \(error.localizedDescription)")
        }

        // XSmall resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xSmall.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> xSmall resolution: \(error.localizedDescription)")
        }

        // Small resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.small.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> small resolution: \(error.localizedDescription)")
        }

        // Medium resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.medium.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> medium resolution: \(error.localizedDescription)")
        }

        // Large resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.large.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> large resolution: \(error.localizedDescription)")
        }

        // XLarge resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xLarge.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> xLarge resolution: \(error.localizedDescription)")
        }

        // XXLarge resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xxLarge.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> xxLarge resolution: \(error.localizedDescription)")
        }

        // Full resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.fullRes.path)
                          .appendingPathComponent(self.uuid)
        do {
            try fm.removeItem(at: fileUrl)
        } catch {
            print("••> full resolution: \(error.localizedDescription)")
        }
    }
}
