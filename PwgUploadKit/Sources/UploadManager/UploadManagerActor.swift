//
//  UploadManagerActor.swift
//  PwgUploadKit
//
//  Created by Eddy Lelièvre-Berna on 11/01/2026.
//  Copyright © 2026 Piwigo.org. All rights reserved.
//

import os
import CoreData
import Foundation
import PwgKit
import PwgCacheKit

@globalActor
public actor UploadManagerActor {
    
    public static let shared = UploadManagerActor()
    
    // Logs networking activities
    /// sudo log collect --device --start '2025-01-11 15:00:00' --output piwigo.logarchive
    private static let logger = PwgLogger(subsystem: "org.piwigo.uploadKit", category: String(describing: UploadManagerActor.self))
    
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
        /// Comment below lines to debug BGProcessingTask
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
    
    
    // MARK: - Retries of Transient Failures
    /// Number of times a request whose transfer failed in a way worth retrying is re-attempted
    /// on its own before being left to the user.
    private static let maxNberOfRetries = 3
    
    /// Number of retries already granted to each request.
    /// Kept in memory only: the counts are forgotten when the app is relaunched, where
    /// resumeInForeground() re-arms whatever was left in an error state.
    private var nberOfRetries: [NSManagedObjectID : Int] = [:]
    
    /// Grants a retry to a request which failed in a way worth retrying and returns its rank,
    /// or nil once the request exhausted its retries — so that a server which is down for good
    /// leaves the requests in their error state instead of spinning the queue.
    public func grantRetry(toUploadWithID uploadID: NSManagedObjectID) -> Int? {
        let nberOfPastRetries = nberOfRetries[uploadID, default: 0]
        guard nberOfPastRetries < Self.maxNberOfRetries else { return nil }
        nberOfRetries[uploadID] = nberOfPastRetries + 1
        return nberOfPastRetries + 1
    }
    
    /// Forgets the retries granted to a request whose transfer completed.
    public func forgetRetries(ofUploadWithID uploadID: NSManagedObjectID) {
        nberOfRetries[uploadID] = nil
    }
    
    
    // MARK: - Process Next Upload
    public func processNextUpload() async {
        // Should we postpone uploads?
        if UploadVars.shared.isPaused ||
            ProcessInfo.processInfo.isLowPowerModeEnabled ||
            [.serious, .critical].contains(ProcessInfo.processInfo.thermalState) ||
            (UploadVars.shared.wifiOnlyUploading && !ServerVars.shared.isConnectedToWiFi) {
            UploadManagerActor.logger.notice("Uploads postponed: paused: \(UploadVars.shared.isPaused), low-power: \(ProcessInfo.processInfo.isLowPowerModeEnabled), thermal: \(ProcessInfo.processInfo.thermalState.rawValue), Wi-Fi only: \(UploadVars.shared.wifiOnlyUploading), on Wi-Fi: \(ServerVars.shared.isConnectedToWiFi) — \(self.uploadIDsToPrepare.count) to prepare, \(self.uploadIDsToTransfer.count) to transfer")
            return
        }
        
        // First, finish transfers of images if any
        if uploadIDsToFinish.isEmpty == false {
            let uploadIDs = uploadIDsToFinish
            uploadIDsToFinish.removeAll()
            await UploadManager.shared.finishTransferOfUpload(withIDs: uploadIDs, inTaskType: .foreground)
        }
        
        // Second, transfer image if any and allowed
        if await UploadManager.shared.nberOfUploadsInTransfer < UploadVars.shared.maxConnectionsPerHost,
           let uploadID = uploadIDsToTransfer.first {
            uploadIDsToTransfer.removeFirst()
            await UploadManager.shared.transferOrCopyFileOfUpload(withID: uploadID, inTaskType: .foreground)
        }
        
        // Third, prepare image if any and allowed
        if await UploadManager.shared.nberOfUploadsInPreparation < UploadVars.shared.maxNberOfPreparedUploads,
           let uploadID = uploadIDsToPrepare.first {
            uploadIDsToPrepare.removeFirst()
            await UploadManager.shared.prepareUpload(withID: uploadID, inTaskType: .foreground)
        }
    }
}
