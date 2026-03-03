//
//  UploadManager+Finisher.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 01/06/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//

import CoreData
import Photos
import piwigoKit

@UploadManagerActor
extension UploadManager {
    
    // MARK: - Tasks Executed after Uploading
    func finishTransferOfUpload(withID uploadID: NSManagedObjectID) async {
        
        // Retrieve upload request properties
        guard var uploadData = try? UploadProvider().getPropertiesOfUpload(withID: uploadID, inContext: self.uploadBckgContext)
        else {
            // Process next upload if any
            UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Could not retrieve upload request for finsihing!")
            await UploadManagerActor.shared.processNextUpload()
            return
        }
        
        // Update upload status
        uploadData.requestState = .finishing
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Finish transfer…")
        try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        
        // Uploaded with pwg.images.uploadAsync -> Empty the lounge
        try? await emptyLounge(for: uploadData)
        
        // Update upload status
        uploadData.requestState = .finished
        try? UploadProvider().updateUpload(withID: uploadID, properties: uploadData, inContext: self.uploadBckgContext)
        
        // Get number of uploads to complete
        let nberOfUploadsToComplete = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        
        // No more image to transfer?
        if nberOfUploadsToComplete == 0 {
            Task(priority: .background) {
                try? await moderateUploadedImagesIfNeeded()
            }
        }
        
        // Store number, update badge and default album view button
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
        // Process next upload if any
        await UploadManagerActor.shared.processNextUpload()
    }
    
    
    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     */
    fileprivate func emptyLounge(for uploadData: UploadProperties) async throws(PwgKitError)
    {
        // Get user properties
        guard let userURI = URL(string: uploadData.userURIstr),
              let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: userURI)
        else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Continue upload tasks without returning error
            return
        }
        
        // Check session
        let userData = try UserProvider().getPropertiesOfUser(withID: uploadData.userURIstr, inContext: self.uploadBckgContext)
        try await JSONManager.shared.checkSession(ofUserWithID: userID, lastConnected: userData.lastUsed)
        
        // Empty lounge
        try await JSONManager.shared.processImages(withIds: uploadData.imageId, inCategory: uploadData.category)
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
        let (finishedID, _) = UploadProvider().getIDsOfCompletedUploads(onlyInStates: [.finished], deletable: false, inContext: self.uploadBckgContext)
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
        let userData = try UserProvider().getPropertiesOfUser(withID: firstUploadData.userURIstr, inContext: self.uploadBckgContext)
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
