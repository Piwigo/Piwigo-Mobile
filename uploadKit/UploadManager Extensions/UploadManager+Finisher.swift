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
        UploadManager.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Finish transfer…")
        
        // Retrieve upload request in context of actor
        guard let upload = try? self.uploadBckgContext.existingObject(with: uploadID) as? Upload
        else {
            debugPrint("!!!! Could not retrieve upload for ID: \(uploadID.uriRepresentation().lastPathComponent) !!!!")
            return
        }
        
        // Update state of upload resquest and finish upload
        upload.setState(.finishing)
        upload.managedObjectContext?.saveIfNeeded()
        
        // Uploaded with pwg.images.uploadAsync -> Empty the lounge
        try? await emptyLounge(for: upload)

        // Update upload request
        upload.setState(.finished)
        upload.managedObjectContext?.saveIfNeeded()

        // Update counter and app badge
        updateNberOfUploadsToComplete()
    }
    

    // MARK: - Empty Lounge
    /**
     Since Piwigo server 12.0, uploaded images are gathered in a lounge
     and one must trigger manually their addition to the database.
     If not, they will be visible after some delay (12 minutes).
     */
    fileprivate func emptyLounge(for upload: Upload) async throws(PwgKitError) {
        UploadManager.logger.notice("\(upload.objectID.uriRepresentation().lastPathComponent) • Empty lounge")
        // Empty lounge without reporting potential error
        guard let user = upload.user else {
            // Should never happen
            // ► The lounge will be emptied later by the server
            // ► Continue upload tasks without returning error
            return
        }
        
        // Check session
        try await JSONManager.shared.checkSession(ofUserWithID: user.objectID, lastConnected: user.lastUsed)
        
        // Empty lounge
        try await JSONManager.shared.processImages(withIds: upload.imageId, inCategory: upload.category)
    }
}
