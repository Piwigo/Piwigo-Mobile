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
        qos: .utility
    )
    
    // Prevents duplicate instances
    private init() { }
    
    
    // MARK: - Serialised Upload Queue
    private var uploadIDsToPrepare: [NSManagedObjectID] = []
    private var uploadIDsToTransfer: [NSManagedObjectID] = []
    private var uploadIDsToFinish: [NSManagedObjectID] = []
    
    public func addUploadsToPrepare(withIDs uploadIDs: [NSManagedObjectID], beforeOthers: Bool = false) async {
        // Remove duplicates if needed (should never happen)
        let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(uploadIDsToPrepare))
        var uploadIDsToAdd = uploadIDs
        uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
        
        // Append upload requests not already in queue
        if beforeOthers {
            uploadIDsToPrepare.insert(contentsOf: uploadIDsToAdd, at: 0)
        } else {
            uploadIDsToPrepare.append(contentsOf: uploadIDsToAdd)
        }
    }
    
    public func addUploadsToTransfer(withIDs uploadIDs: [NSManagedObjectID], beforeOthers: Bool = false) async {
        // Remove duplicates if needed (should never happen)
        let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(uploadIDsToTransfer))
        var uploadIDsToAdd = uploadIDs
        uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
        
        // Append upload requests not already in queue
        if beforeOthers {
            uploadIDsToTransfer.insert(contentsOf: uploadIDsToAdd, at: 0)
        } else {
            uploadIDsToTransfer.append(contentsOf: uploadIDsToAdd)
        }
    }
    
    public func addUploadsToFinish(withIDs uploadIDs: [NSManagedObjectID]) async {
        // Remove duplicates if needed (should never happen)
        let alreadyQueuedIDs = Set(uploadIDs).intersection(Set(uploadIDsToFinish))
        var uploadIDsToAdd = uploadIDs
        uploadIDsToAdd.removeAll(where: { alreadyQueuedIDs.contains($0) })
        
        // Append upload requests not already in queue
        uploadIDsToFinish.append(contentsOf: uploadIDsToAdd)
    }
    
    public func removeUploads(withIDs uploadIDs: [NSManagedObjectID]) async {
        // Remove upload request from queue
        uploadIDsToPrepare.removeAll(where: { uploadIDs.contains($0) })
        uploadIDsToTransfer.removeAll(where: { uploadIDs.contains($0) })
    }
    
    public func removeAllUploads() async {
        uploadIDsToPrepare.removeAll()
        uploadIDsToTransfer.removeAll()
        
        // Update badge and default album view button
        await UploadManager.shared.updateNberOfUploadsToComplete()
    }

    public func processNextUpload() async {
        // Should we postpone uploads?
        if UploadVars.shared.isPaused ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            (UploadVars.shared.wifiOnlyUploading && !NetworkVars.shared.isConnectedToWiFi) {
            return
        }
        
        // First, finish transfers of images if any
        if uploadIDsToFinish.isEmpty == false {
            let uploadIDs = uploadIDsToFinish
            uploadIDsToFinish.removeAll()
            await UploadManager.shared.finishTransferOfUpload(withIDs: uploadIDs)
        }
        
        // Second, transfer image if any and allowed
        if await UploadManager.shared.nberOfUploadsInTransfer < UploadVars.shared.maxNberOfUploadTransfers,
           let uploadID = uploadIDsToTransfer.first {
            uploadIDsToTransfer.removeFirst()
            await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID)
        }
        
        // Third, prepare image if any and allowed
        if await UploadManager.shared.nberOfUploadsInPreparation < UploadVars.shared.maxNberOfPreparedUploads,
           let uploadID = uploadIDsToPrepare.first {
            uploadIDsToPrepare.removeFirst()
            await UploadManager.shared.prepareUpload(withID: uploadID)
        }
    }
}
