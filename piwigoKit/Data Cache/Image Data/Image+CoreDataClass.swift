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

/* Image instances represent photos and videos of a Piwigo server.
    - Each instance belongs to a Server.
    - Image files are stored in cache, in a folder belonging to the appropriate server.
    - Image files are automatically deleted from the cache when deleting an instance.
 */
public class Image: NSManagedObject {
    /**
     Updates an Image instance with the values from a ImagesGetInfo struct.
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
        
        // Image title
        if let newTitle = imageData.title {
            let titleUTF8 = NetworkUtilities.utf8mb4String(from: newTitle)
            let titleAttrStr = titleUTF8.htmlToAttributedString
            if title.string != titleUTF8 {
                title = titleAttrStr
                titleStr = titleUTF8
            }
        }
        
        // Image description
        if let desc = imageData.comment {
            let newDesc = NetworkUtilities.utf8mb4String(from: desc).htmlToAttributedString
            if comment.string != newDesc.string {
                comment = newDesc
            }
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
            dateGetInfos = Date()       // Remember when pwg.images.getInfos is called
            fileSize = newSize
        }

        let newMD5 = imageData.md5checksum ?? ""
        if newMD5.isEmpty == false, md5sum != newMD5 {
            md5sum = newMD5
        }
        let newFile = NetworkUtilities.utf8mb4String(from: imageData.fileName ?? "")
        if newFile.isEmpty == false {
            if fileName != newFile {
                fileName = newFile
            }
            let fileExt = URL(fileURLWithPath: newFile).pathExtension as NSString
            if fileExt.length > 0,
               let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt, nil)?.takeRetainedValue() {
                let newIsVideo = UTTypeConformsTo(uti, kUTTypeMovie)
                if isVideo != newIsVideo {
                    isVideo = newIsVideo
                }
            }
        }
        
        // Image dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let unknownDate = dateFormatter.date(from: "1900-01-01 00:00:00")!
        let newPosted = dateFormatter.date(from: imageData.datePosted ?? "") ?? unknownDate
        if newPosted > unknownDate, datePosted != newPosted {
            datePosted = newPosted
        }
        let newCreated = dateFormatter.date(from: imageData.dateCreated ?? "") ?? unknownDate
        if newCreated > unknownDate, dateCreated != newCreated {
            dateCreated = newCreated
        }
        
        // Author
        if let newAuthor = imageData.author {
           let newAuthorUTF8 = NetworkUtilities.utf8mb4String(from: newAuthor)
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
                                 imageURL: NSURL(string: fullResUrl?.absoluteString ?? ""))
        if fullRes == nil || fullRes?.isEqual(newFull) == false {
            fullRes = newFull
        }

        // Derivatives
        let square = imageData.derivatives.squareImage
        let squareUrl = NetworkUtilities.encodedImageURL(square?.url ?? "")
        let newSquare = Resolution(imageWidth: square?.width?.intValue ?? 1,
                                   imageHeight: square?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: squareUrl?.absoluteString ?? ""))
        if squareRes == nil || squareRes?.isEqual(newSquare) == false {
            squareRes = newSquare
        }
        
        let thumb = imageData.derivatives.thumbImage
        let thumbUrl = NetworkUtilities.encodedImageURL(thumb?.url ?? "")
        let newThumb = Resolution(imageWidth: thumb?.width?.intValue ?? 1,
                                  imageHeight: thumb?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: thumbUrl?.absoluteString ?? ""))
        if thumbRes == nil || thumbRes?.isEqual(newThumb) == false {
            thumbRes = newThumb
        }
        
        let medium = imageData.derivatives.mediumImage
        let mediumUrl = NetworkUtilities.encodedImageURL(medium?.url ?? "")
        let newMedium = Resolution(imageWidth: medium?.width?.intValue ?? 1,
                                   imageHeight: medium?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: mediumUrl?.absoluteString ?? ""))
        if mediumRes == nil || mediumRes?.isEqual(newMedium) == false {
            mediumRes = newMedium
        }
        
        let small = imageData.derivatives.smallImage
        let smallUrl = NetworkUtilities.encodedImageURL(small?.url ?? "")
        let newSmall = Resolution(imageWidth: small?.width?.intValue ?? 1,
                                  imageHeight: small?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: smallUrl?.absoluteString ?? ""))
        if smallRes == nil || smallRes?.isEqual(newSmall) == false {
            smallRes = newSmall
        }
        
        let xsmall = imageData.derivatives.xSmallImage
        let xsmallUrl = NetworkUtilities.encodedImageURL(xsmall?.url ?? "")
        let newXsmall = Resolution(imageWidth: xsmall?.width?.intValue ?? 1,
                                   imageHeight: xsmall?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xsmallUrl?.absoluteString ?? ""))
        if xsmallRes == nil || xsmallRes?.isEqual(newXsmall) == false {
            xsmallRes = newXsmall
        }
        
        let xxsmall = imageData.derivatives.xxSmallImage
        let xxsmallUrl = NetworkUtilities.encodedImageURL(xxsmall?.url ?? "")
        let newXxsmall = Resolution(imageWidth: xxsmall?.width?.intValue ?? 1,
                                    imageHeight: xxsmall?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxsmallUrl?.absoluteString ?? ""))
        if xxsmallRes == nil || xxsmallRes?.isEqual(newXxsmall) == false {
            xxsmallRes = newXxsmall
        }
        
        let large = imageData.derivatives.largeImage
        let largeUrl = NetworkUtilities.encodedImageURL(large?.url ?? "")
        let newLarge = Resolution(imageWidth: large?.width?.intValue ?? 1,
                                  imageHeight: large?.height?.intValue ?? 1,
                                  imageURL: NSURL(string: largeUrl?.absoluteString ?? ""))
        if largeRes == nil || largeRes?.isEqual(newLarge) == false {
            largeRes = newLarge
        }
        
        let xlarge = imageData.derivatives.xLargeImage
        let xlargeUrl = NetworkUtilities.encodedImageURL(xlarge?.url ?? "")
        let newXlarge = Resolution(imageWidth: xlarge?.width?.intValue ?? 1,
                                   imageHeight: xlarge?.height?.intValue ?? 1,
                                   imageURL: NSURL(string: xlargeUrl?.absoluteString ?? ""))
        if xlargeRes == nil || xlargeRes?.isEqual(newXlarge) == false {
            xlargeRes = newXlarge
        }
        
        let xxlarge = imageData.derivatives.xxLargeImage
        let xxlargeUrl = NetworkUtilities.encodedImageURL(xxlarge?.url ?? "")
        let newXxlarge = Resolution(imageWidth: xxlarge?.width?.intValue ?? 1,
                                    imageHeight: xxlarge?.height?.intValue ?? 1,
                                    imageURL: NSURL(string: xxlargeUrl?.absoluteString ?? ""))
        if xxlargeRes == nil || xxlargeRes?.isEqual(newXxlarge) == false {
            xxlargeRes = newXxlarge
        }
        
        // Rank of image in album
        switch sort {
        case .manual:
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
        let cacheUrl = DataDirectories.shared.cacheDirectory
            .appendingPathComponent(serverUUID)

        // Square resolution
        var fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.square.path)
                              .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Square resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> square resolution: \(error.localizedDescription)")
        }
        
        // Thumbnail resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.thumb.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Thumbnail resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> thumbnail resolution: \(error.localizedDescription)")
        }
        
        // XXSmall resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xxSmall.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> XXSmall resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> xxSmall resolution: \(error.localizedDescription)")
        }

        // XSmall resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xSmall.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> XSmall resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> xSmall resolution: \(error.localizedDescription)")
        }

        // Small resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.small.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Small resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> small resolution: \(error.localizedDescription)")
        }

        // Medium resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.medium.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Medium resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> medium resolution: \(error.localizedDescription)")
        }

        // Large resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.large.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Large resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> large resolution: \(error.localizedDescription)")
        }

        // XLarge resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xLarge.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> XLarge resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> xLarge resolution: \(error.localizedDescription)")
        }

        // XXLarge resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.xxLarge.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> XXLarge resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> xxLarge resolution: \(error.localizedDescription)")
        }

        // Full resolution
        fileUrl = cacheUrl.appendingPathComponent(pwgImageSize.fullRes.path)
                          .appendingPathComponent(String(self.pwgID))
        do {
            try fm.removeItem(at: fileUrl)
            print("••> Full resolution image \(self.pwgID) deleted from cache.")
        } catch {
            print("••> full resolution: \(error.localizedDescription)")
        }
    }
}
