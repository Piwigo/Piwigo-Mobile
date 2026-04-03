//
//  UploadManager.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/05/2020.
//  Copyright © 2020 Piwigo.org. All rights reserved.
//
// See https://academy.realm.io/posts/gwendolyn-weston-ios-background-networking/

import os
import Foundation
import CoreData
import piwigoKit

@UploadManagerActor
public final class UploadManager {
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadManager.self))
    
    // Singleton
    public static let shared = UploadManager()
        
    // Upload counters kept in memory during upload
    // for updating progress bars and managing tasks
    var transferCounters = [TransferCounter]()
    
    private init() {
        // Register auto-upload disabler
        NotificationCenter.default.addObserver(self, selector: #selector(stopAutoUploader(_:)),
                                               name: Notification.Name.pwgDisableAutoUpload, object: nil)
    }
    
    deinit {
        // Unregister all observers
        NotificationCenter.default.removeObserver(self)
    }
    
    
    // MARK: - CoreData Context
    public lazy var uploadBckgContext: NSManagedObjectContext = {
        return DataController.shared.newTaskContext()
    }()
    
    
    // MARK: - CoreData Utilities
    public func importUploads(from uploadRequest: [UploadProperties]) async throws -> [NSManagedObjectID] {
        // Create upload requests
        let uploadIDs = try await UploadProvider().importUploads(from: uploadRequest, inContext: uploadBckgContext)
        
        // Store number, update badge and default album view button (even in Low Power mode)
        self.updateNberOfUploadsToComplete()
        
        return uploadIDs
    }
    
    // Number of upload requests prepared to being prepared
    var nberOfUploadsInPreparation: Int {
        let states: [pwgUploadState] = [.prepared, .preparing]
        let (inPreparation, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        return inPreparation.count
    }
    
    // Number of uploads in transfer
    var nberOfUploadsInTransfer: Int {
        let states: [pwgUploadState] = [.uploading, .uploaded]
        let (inTransfer, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        return inTransfer.count
    }
    
    /// Number of pending upload requests
    public func updateNberOfUploadsToComplete() {
        // Get number of uploads to complete
        UploadVars.shared.nberOfUploadsToComplete = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        
        // Store number, update badge and default album view button
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : UploadVars.shared.nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgUpdateNberOfUploadsToComplete, object: nil, userInfo: uploadInfo)
        }
    }
}
