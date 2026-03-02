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
        
        // Update counter and app badge
        updateNberOfUploadsToComplete()
        
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
        // Empty lounge without reporting potential error
        guard let objectURI = URL(string: uploadData.userID),
              let userID = uploadBckgContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURI),
              let user = try? uploadBckgContext.existingObject(with: userID) as? User
        else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Continue upload tasks without returning error
            return
        }
        
        // Check session
        try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
        
        // Empty lounge
        try await JSONManager.shared.processImages(withIds: uploadData.imageId, inCategory: uploadData.category)
    }
}
