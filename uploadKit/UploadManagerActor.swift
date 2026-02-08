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
    static let logger = Logger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadManagerActor.self))
    
    private init() { }   // Prevents duplicate instances
    
    
    // MARK: - Serialised Upload Queue
    private var isUploading = false
    private var uploadQueue: [NSManagedObjectID] = []
    
    public func addUploads(withIDs uploadIDs: [NSManagedObjectID]) async {
        let uploadIDsSet = Set(uploadIDs)
        uploadQueue.append(contentsOf: uploadIDsSet.subtracting(Set(uploadQueue)))
        await processNextUpload()
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
        
        guard !isUploading, let uploadID = uploadQueue.first
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
