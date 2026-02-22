//
//  UploadManagerActor.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 11/01/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import piwigoKit

@globalActor
public actor UploadManagerActor {
    
    public static let shared = UploadManagerActor()
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    private static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadManagerActor.self))
    
    // The serial executor drives all actor-isolated work on this queue
    private static let queue = DispatchQueue(
        label: "org.piwigo.uploadKit.queue",
        qos: .userInteractive
    )
    
    // Prevents duplicate instances
    private init() { }
    
    
    // MARK: - Serialised Upload Queue
    private var isUploading = false
    private var uploadQueue: [NSManagedObjectID] = []
    
    public func addUploads(withIDs uploadIDs: [NSManagedObjectID]) async {
        // Remove duplicate if needed (should never happen)
        let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(uploadQueue))
        var uploadIDsToQueue = uploadIDs
        uploadIDsToQueue.removeAll(where: { alreadyQueuedIDs.contains($0) })
        
        // Append upload requests not already in queue
        uploadQueue.append(contentsOf: uploadIDsToQueue)
        await processNextUpload()
    }
    
    public func removeUploads(withIDs uploadIDs: [NSManagedObjectID]) async {
        // Remove upload request from queue
        uploadQueue.removeAll(where: { uploadIDs.contains($0) })
        
        // Update badge and default album view button
        await UploadManager.shared.updateNberOfUploadsToComplete()
    }
    
    public func processNextUpload() async {
        // Should we postpone uploads?
        if UploadVars.shared.isPaused ||
//            UploadVars.shared.isExecutingBGUploadTask ||
//            UploadVars.shared.isExecutingBGContinuedUploadTask ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi) {
            return
        }
        
        guard await UploadManager.shared.nberOfUploadsInPreparation() <= maxNberOfUploadsInPrepartion,
              await UploadManager.shared.nberOfUploadsInTransferOrCopyQueue() <= maxNberOfUploadsInTransferOrCopyQueue,
              !isUploading, let uploadID = uploadQueue.first
        else { return }
        
        isUploading = true
        uploadQueue.removeFirst()
        
        // Prepare and transfer if upload request in apropriate state
        await UploadManager.shared.prepareUpload(withID: uploadID)
        await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
        
        isUploading = false
        await processNextUpload() // Recursive call for next item
    }
    
    // Patch because one cannot retrieve AVAsset with async function
    public func processVideo(ofUploadWithID uploadID: NSManagedObjectID) async {
        UploadManagerActor.logger.notice("\(uploadID.uriRepresentation().lastPathComponent) • Process video")
        await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
        
        isUploading = false
        await processNextUpload() // Recursive call for next item
    }
}
