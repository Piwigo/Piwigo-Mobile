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
    
    
    // MARK: - Upload Request States
    /** The manager prepares an image for upload and then launches the transfer.
     - isPreparing is set to true when a photo/video is going to be prepared,
     and false when the preparation has completed or failed.
     - isUploading contains the localIdentifier of the photos/videos being transferred to the server,
     - isFinishing is set to true when the photo/video parameters are going to be set,
     and false when this job has completed or failed.
     */
    //    var isPreparing = false                                 // Prepare one image at once
    //    var isUploading = Set<NSManagedObjectID>()              // IDs of queued transfers
    //    var isFinishing = false                                 // Finish transfer one image at once
    //    var isDeleting = Set<NSManagedObjectID>()               // IDs of uploads to be deleted
    
//    public var countOfBytesPrepared = UInt64(0)             // Total amount of bytes of prepared files
//    public var countOfBytesToUpload = 0                     // Total amount of bytes to be sent
    public var uploadRequestsToPrepare = [NSManagedObjectID]()
    public var uploadRequestsToTransfer = [NSManagedObjectID]()
    
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
        debugPrint("In uploadBckgContext ► Thread priority: \(Task.currentPriority)")
        return DataController.shared.newTaskContext()
    }()
    
    
    // MARK: - CoreData Utilities
    public func importUploads(from uploadRequest: [UploadProperties]) async throws -> [NSManagedObjectID] {
        // Create upload requests
        let uploadIDs = try await UploadProvider().importUploads(from: uploadRequest, inContext: uploadBckgContext)
        
        // Store number, update badge and default album view button (even in Low Power mode)
        let nberOfPendingUploads = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfPendingUploads]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
        
        return uploadIDs
    }
    
    // Number of upload requests prepared to being prepared
    var nberOfUploadsInPreparation: Int {
        let states: [pwgUploadState] = [.prepared, .preparing]
        let (inPreparation, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: states, inContext: self.uploadBckgContext)
        return inPreparation.count
    }
    
    // Number of uploads to transfer
    var nberOfUploadsToTransfer: Int {
        let (inTransfer, _) = UploadProvider().getIDsOfPendingUploads(onlyInStates: [.uploading], inContext: self.uploadBckgContext)
        return inTransfer.count
    }
    
    /// Number of pending upload requests
    public func updateNberOfUploadsToComplete() {
        // Get number of uploads to complete
        let nberOfUploadsToComplete = UploadProvider().getCountOfPendingUploads(inContext: self.uploadBckgContext)
        
        // Store number, update badge and default album view button
        DispatchQueue.main.async {
            // Update app badge and button of root album (or default album)
            let uploadInfo: [String : Any] = ["nberOfUploadsToComplete" : nberOfUploadsToComplete]
            NotificationCenter.default.post(name: .pwgLeftUploads, object: nil, userInfo: uploadInfo)
        }
    }
}
