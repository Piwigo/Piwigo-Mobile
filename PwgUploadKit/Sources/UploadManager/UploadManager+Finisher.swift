//
//  UploadManager+Finisher.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import BackgroundTasks
import CoreData
import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Tasks Executed after Uploading
    func finishTransferOfUpload(withIDs uploadIDs: [NSManagedObjectID], inTaskType taskType: UploadTaskType) async {
        
        // Retrieve upload request properties
        var uploadDataArray: [NSManagedObjectID : UploadProperties] = [:]
        for uploadID in uploadIDs {
            guard let uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
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
            return
        }
        
        // Update upload status
        uploadDataArray.forEach { (uploadID,_) in
            guard var uploadData = uploadDataArray[uploadID] else { return }
            uploadData.requestState = .finishing
            uploadData.requestError = ""
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • The transfer is now being finalised…")
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
        
        // Uploaded with pwg.images.uploadAsync -> Empty lounge
        try? await emptyLounge(for: Array(uploadDataArray.values))
        
        // Update upload status
        uploadDataArray.forEach { (uploadID,_) in
            guard var uploadData = uploadDataArray[uploadID] else { return }
            uploadData.requestState = .finished
            uploadData.requestError = ""
            try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        }
        
        // Update number of uploads to complete, badge and default album view button
        self.updateNberOfUploadsToComplete()
        
        // No more image to transfer?
        if UploadVars.shared.nberOfUploadsToComplete == 0 {
            // Moderate uploaded images if needed
            try? await moderateUploadedImagesIfNeeded()
            
            // Suggest to delete uploaded images if needed
            if UploadVars.shared.isApplicationActive {
                suggestToDeleteUploadedImages(withPendingUploads: 0)
            }
        }
        
        // In foreground, process next upload if any
        if taskType.isForeground {
            await UploadManagerActor.shared.processNextUpload()
        }
    }
    
    
    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     */
    fileprivate func emptyLounge(for uploadDataArray: [UploadProperties]) async throws(PwgKitError)
    {
        // Check that at least one upload is provided
        if uploadDataArray.isEmpty { return }
        
        // Loop over albums
        let albumIds = Set(uploadDataArray.map({ $0.category }))
        for albumId in albumIds {

            // Get uploads concerning that album
            let uploadDataArrayForAlbum = uploadDataArray.filter({ $0.category == albumId })
            if uploadDataArrayForAlbum.isEmpty { continue }
            
            // Get user properties
            guard let userURI = URL(string: uploadDataArrayForAlbum[0].userURIstr),
                  let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI)
            else {
                // Should never happen
                // ► The lounge will be emptied later by the server
                // ► Continue upload tasks without returning error
                return
            }
            
            // Check session
            let userData = try UserProvider().getPropertiesOfUser(withURIstr: uploadDataArrayForAlbum[0].userURIstr, inContext: self.uploadBckgContext)
            try await JSONManager.shared.checkSession(ofUserWithID: userID, lastConnected: userData.lastUsed)
            
            // Empty lounge
            let imageIds = uploadDataArrayForAlbum.map({ $0.imageId })
            try await JSONManager.shared.processImages(withIds: imageIds, inCategory: albumId)
        }
    }
    
    
    // MARK: - Moderate Images Uploaded by Community User
    func moderateUploadedImagesIfNeeded() async throws(PwgKitError) -> Void
    {
        // Normal user?
        if (NetworkVars.shared.usesCommunityPluginV29
            && NetworkVars.shared.userStatus == .normal) == false {
            return
        }
        
        // Are there uploaded images to moderate?
        // Considers only uploads to the server to which the user is logged in
        let (finishedID, _) = UploadProvider().getIDsOfCompletedUploads(onlyInStates: [.finished], inContext: self.uploadBckgContext)
        if finishedID.isEmpty { return }
        
        // Get user properties
        guard let firstUploadID = finishedID.first,
              let firstUploadData = try? UploadProvider().getPropertiesOfUpload(withID: firstUploadID, inContext: self.uploadBckgContext),
              let userURI = URL(string: firstUploadData.userURIstr),
              let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI)
        else {
            // Should never happen
            // ► The moderator will be informed later
            return
        }
        
        // Check session
        let userData = try UserProvider().getPropertiesOfUser(withURIstr: firstUploadData.userURIstr, inContext: self.uploadBckgContext)
        try await JSONManager.shared.checkSession(ofUserWithID: userID, lastConnected: userData.lastUsed)

        // Get properties of upload requests
        var allUploadData: [(NSManagedObjectID, UploadProperties)] = []
        finishedID.forEach { uploadID in
            if let uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext) {
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
            
            // Moderate updated images
            let validatedImageIDs = try await JSONManager.shared.moderateImages(withIds: imageIDs, inCategory: categoryId)
            
            // Update upload requests
            let uploadDataToUpdate = categoryUploadData.filter({ validatedImageIDs.contains($1.imageId) })
            uploadDataToUpdate.forEach { (uploadID, uploadData) in
                var newUploadData = uploadData
                newUploadData.requestState = .moderated
                newUploadData.requestError = ""
                try? UploadProvider().updateUpload(withID: uploadID, properties: newUploadData, inContext: self.uploadBckgContext)
            }
        }
    }
}
