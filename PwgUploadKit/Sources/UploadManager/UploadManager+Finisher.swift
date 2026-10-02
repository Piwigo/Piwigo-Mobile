//
//  UploadManager+Finisher.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Photos
import PwgKit
import PwgAPIKit
import PwgCacheKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Tasks Executed after Uploading
    /// Returns the IDs of the uploaded images which may be shown in their album,
    /// i.e. not those of a Community user which are pending moderation.
    @discardableResult
    func finishTransferOfUpload(withIDs uploadIDs: [NSManagedObjectID],
                                inTaskType taskType: UploadTaskType) async -> Set<Int64> {
        
        // Retrieve upload request properties
        var uploadDataArray: [NSManagedObjectID : UploadProperties] = [:]
        for uploadID in uploadIDs {
            guard let uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID,
                                                                               inContext: self.uploadBckgContext)
            else {
                UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for finsihing!")
                continue
            }
            // Check upload status (should never happen)
            guard uploadData.requestState == .uploaded
            else { continue }
            uploadDataArray[uploadID] = uploadData
        }
        if uploadDataArray.isEmpty {
            // Should we process a next upload?
            if taskType.isForeground {
                await UploadManagerActor.shared.processNextUpload()
            }
            return []
        }
        
        // Update upload status
        uploadDataArray.forEach { (uploadID,_) in
            guard var uploadData = uploadDataArray[uploadID] else { return }
            uploadData.requestState = .finishing
            uploadData.requestError = ""
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • The transfer is now being finalised…")
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData,
                                               inContext: self.uploadBckgContext)
        }
        
        // Uploaded with pwg.images.uploadAsync -> Empty lounge
        let (visibleImageIDs, moderatedImageIDs) = await emptyLounge(for: Array(uploadDataArray.values))
        
        // Update upload status
        /// Images of a Community user still to be submitted to the moderator remain in the finished state,
        /// as well as those whose lounge will be emptied at the end of the series.
        uploadDataArray.forEach { (uploadID,_) in
            guard var uploadData = uploadDataArray[uploadID] else { return }
            uploadData.requestState = moderatedImageIDs.contains(uploadData.imageId) ? .moderated : .finished
            uploadData.requestError = ""
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData,
                                               inContext: self.uploadBckgContext)
        }
        
        // Update number of uploads to complete, badge and default album view button
        self.updateNberOfUploadsToComplete()
        
        // No more image to transfer?
        if UploadVars.shared.nberOfUploadsToComplete == 0 {
            // Moderate uploaded images if needed
            try? await moderateUploadedImagesIfNeeded()
            
            // The moderation of the next series will be learned again
            moderationOfAlbums.removeAll()
            
            // Suggest to delete uploaded images if needed
            if UploadVars.shared.isApplicationActive {
                suggestToDeleteUploadedImages(withPendingUploads: 0)
            }
        }
        
        // In foreground, process next upload if any
        if taskType.isForeground {
            await UploadManagerActor.shared.processNextUpload()
        }
        
        return visibleImageIDs
    }
    
    
    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     
     The images uploaded by an admin are shown at once. Those uploaded by a Community user are
     only shown once the state returned by the moderation of the first image of the series
     uploaded to the album shows that the user has high trust in that album. When it shows that
     the images are pending moderation, the lounge of the remaining images is emptied and the
     moderator informed at the end of the series, see moderateUploadedImagesIfNeeded().
     
     Returns the IDs of the images which may be shown in their album,
     and of those which were submitted to the moderator or need not be.
     */
    fileprivate func emptyLounge(for uploadDataArray: [UploadProperties]) async
        -> (visible: Set<Int64>, moderated: Set<Int64>)
    {
        var visibleImageIDs = Set<Int64>(), moderatedImageIDs = Set<Int64>()
        
        // Loop over albums
        let albumIds = Set(uploadDataArray.map({ $0.category }))
        for albumId in albumIds {
            
            // Get uploads concerning that album
            let uploadDataArrayForAlbum = uploadDataArray.filter({ $0.category == albumId })
            guard let userURIstr = uploadDataArrayForAlbum.first?.userURIstr,
                  var userData = try? UserProvider().getPropertiesOfUser(withURIstr: userURIstr,
                                                                         inContext: self.uploadBckgContext)
            else { continue }
            let imageIds = uploadDataArrayForAlbum.map({ $0.imageId })
            
            // Images uploaded by a Community user are moderated
            let isCommunityUser = ServerVars.shared.usesCommunityPluginV29
                && pwgUserStatus(rawValue: userData.status) == .normal
            let album = AlbumOfUser(userURIstr: userURIstr, albumId: albumId)
            
            // Images pending moderation?
            /// The lounge will be emptied and the moderator informed at the end of the series,
            /// which saves a request per uploaded image.
            if isCommunityUser, moderationOfAlbums[album] == .pending {
                continue
            }
            
            // Empty lounge
            let nbImages: Int64?
            do {
                try await checkSession(ofUser: &userData)
                nbImages = try await JSONManager.shared.processImages(withIds: imageIds, inCategory: albumId)
            }
            catch {
                // The server will add the images to the album after some delay
                UploadManager.logger.notice("Album #\(albumId) • Could not empty the lounge: \(error.localizedDescription)")
                if isCommunityUser == false {
                    visibleImageIDs.formUnion(imageIds)
                }
                continue
            }
            
            // Are the images validated at once?
            if isCommunityUser == false {
                // Images uploaded by an admin are shown at once
                visibleImageIDs.formUnion(imageIds)
            }
            else if moderationOfAlbums[album] == .validated {
                // High trust ► Shown at once, no need to inform the moderator
                visibleImageIDs.formUnion(imageIds)
                moderatedImageIDs.formUnion(imageIds)
            }
            else {
                // Submit the images to the moderator to learn the trust of the user in that album
                let imageIDs = imageIds.map({ String($0) }).joined(separator: ",")
                guard let pendingIDs = try? await JSONManager.shared.moderateImages(withIds: imageIDs,
                                                                                    inCategory: albumId)
                else {
                    // The next image uploaded to that album will be submitted
                    UploadManager.logger.notice("Album #\(albumId) • Could not submit uploaded images to the moderator")
                    continue
                }
                /// The images validated at once are not listed by the server.
                moderatedImageIDs.formUnion(imageIds)
                visibleImageIDs.formUnion(Set(imageIds).subtracting(pendingIDs))
                
                // The images are counted only if they were all validated
                if pendingIDs.isDisjoint(with: imageIds) {
                    // High trust ► The next images uploaded to that album will be shown at once
                    moderationOfAlbums[album] = .validated
                } else {
                    // Low trust ► The next images uploaded to that album will be moderated
                    moderationOfAlbums[album] = .pending
                    continue
                }
            }
            
            // Update the number of images of the album
            /// The images are not counted one by one while they are uploaded, because the server
            /// gathers them in a lounge and only adds them to the album now. Its own count is
            /// therefore adopted as a whole, and a server which does not return one leaves the
            /// uploaded images to be counted. Since that count includes the images pending
            /// moderation, it is only adopted when the uploaded images are visible.
            if let nbImages {
                try? AlbumProvider().updateAlbums(withNberOfImages: nbImages, ofAlbumWithID: albumId,
                                                  belongingToUser: userURIstr,
                                                  inContext: self.uploadBckgContext)
            } else {
                try? AlbumProvider().updateAlbums(addingImages: Int64(imageIds.count), toAlbumWithID: albumId,
                                                  belongingToUser: userURIstr,
                                                  inContext: self.uploadBckgContext)
            }
        }
        return (visibleImageIDs, moderatedImageIDs)
    }
    
    
    // MARK: - Moderate Images Uploaded by Community User
    func moderateUploadedImagesIfNeeded() async throws(PwgKitError) -> Void
    {
        // Are there uploaded images to moderate?
        // Considers only uploads to the server to which the user is logged in
        let (finishedID, _) = UploadProvider().getIDsOfCompletedUploads(onlyInStates: [.finished],
                                                                        inContext: self.uploadBckgContext)
        if finishedID.isEmpty { return }
        
        // Get user properties
        guard let firstUploadID = finishedID.first,
              let firstUploadData = try? UploadProvider().getPropertiesOfUpload(withID: firstUploadID,
                                                                                inContext: self.uploadBckgContext)
        else {
            // Should never happen
            // ► The moderator will be informed later
            return
        }
        
        // Community user?
        var userData = try UserProvider().getPropertiesOfUser(withURIstr: firstUploadData.userURIstr,
                                                              inContext: self.uploadBckgContext)
        if (ServerVars.shared.usesCommunityPluginV29
            && pwgUserStatus(rawValue: userData.status) == .normal) == false {
            return
        }
        
        // Check session
        try await checkSession(ofUser: &userData)
        
        // Get properties of upload requests
        var allUploadData: [(NSManagedObjectID, UploadProperties)] = []
        finishedID.forEach { uploadID in
            if let uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID,
                                                                            inContext: self.uploadBckgContext) {
                allUploadData.append((uploadID, uploadData))
            }
        }
        if allUploadData.isEmpty { return }
        
        // Determine list of categories
        let categories: Set<Int32> = Set(allUploadData.compactMap { $1.category })
        if categories.isEmpty { return }
        
        // Moderate images by category
        for categoryId in categories {
            // Extract list of images to moderate in that category
            let categoryUploadData = allUploadData.filter({$1.category == categoryId})
            let imageIDs = String(categoryUploadData.map({ "\($1.imageId)," }).reduce("", +).dropLast())
            
            // Empty the lounge of the images uploaded to albums in which the user has low trust
            /// The server count of images is not adopted since it includes the images pending moderation.
            /// Images already added to the album are ignored by the server.
            do {
                try await JSONManager.shared.processImages(withIds: categoryUploadData.map({ $1.imageId }),
                                                           inCategory: categoryId)
            }
            catch {
                // The server will add the images to the album after some delay
                UploadManager.logger.notice("Album #\(categoryId) • Could not empty the lounge: \(error.localizedDescription)")
            }
            
            // Moderate updated images
            /// The images validated at once are not listed by the server.
            let _ = try await JSONManager.shared.moderateImages(withIds: imageIDs, inCategory: categoryId)
            
            // Update upload requests
            categoryUploadData.forEach { (uploadID, uploadData) in
                var newUploadData = uploadData
                newUploadData.requestState = .moderated
                newUploadData.requestError = ""
                try? UploadProvider().updateUpload(withID: uploadID, properties: newUploadData,
                                                   inContext: self.uploadBckgContext)
            }
        }
    }
}


// MARK: - Moderation of Albums
/// Album of a user to which images were uploaded during the current series
struct AlbumOfUser: Hashable {
    let userURIstr: String
    let albumId: Int32
}

/// Moderation applied to the images uploaded by a Community user to an album
enum CommunityModeration {
    case validated      /* High trust: the images are validated at once */
    case pending        /* Low trust: the images are pending moderation */
}
