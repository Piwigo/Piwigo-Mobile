//
//  UploadManager+TransferCounter.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 23/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

@UploadManagerActor
extension UploadManager {
    
    struct TransferCounter {
        var uid: String
        var chunksToSend: Set<Int>      // List of chunks not yet sent
        var totalBytes: Int64           // Bytes to upload
        var bytesSent: Int64            // Bytes sent
        var progress: Float {           // Overall progress fraction
            get {
                if totalBytes == .zero { return 0.1 }
                return min(Float(bytesSent) / Float(totalBytes), 1.0)
            }
        }
        
        init(identifier: String) {
            self.uid = identifier
            self.chunksToSend = Set<Int>()
            self.totalBytes = Int64.zero
            self.bytesSent = Int64.zero
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.uid == rhs.uid
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uid)
        }
    }
    
    // Initialise a counter before resuming upload tasks
    func initIfNeededCounter(withID objectIDstr: String, chunk: Int? = nil, chunks: Int? = nil) {
        if transferCounters.contains(where: {$0.uid == objectIDstr}) {
#if DEBUG
            UploadManager.logger.notice("\(objectIDstr) • Counter already exists")
#endif
        }
        else {
            var newCounter = TransferCounter(identifier: objectIDstr)
            if let chunks {
                newCounter.chunksToSend = Set(1...chunks)
            }
            if let chunk {
                newCounter.chunksToSend.remove(chunk)
            }
            transferCounters.append(newCounter)
#if DEBUG
            UploadManager.logger.notice("\(objectIDstr) • Initialise counter")
#endif
        }
    }
    
    // Set chunk series and total number of bytes to upload
    func setCounter(withID objectIDstr: String, chunks: Int, totalBytes: Int64) {
        if let index = transferCounters.firstIndex(where: {$0.uid == objectIDstr}) {
            transferCounters[index].chunksToSend = Set(1...chunks)
            transferCounters[index].totalBytes = totalBytes
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: totalBytes)) ?? ""
            UploadManager.logger.notice("\(objectIDstr) • Set counter to \(chunks) chunks totalising \(value) bytes")
#endif
        }
        else {  // Situation where the app was relauched
            var newCounter = TransferCounter(identifier: objectIDstr)
            newCounter.chunksToSend = Set(1...chunks)
            newCounter.totalBytes = totalBytes
            transferCounters.append(newCounter)
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: totalBytes)) ?? ""
            UploadManager.logger.notice("\(objectIDstr) • Reset counter to \(chunks) chunks totalising \(value) bytes")
#endif
        }
    }
    
    // Remove chunk sent to server
    func removeChunk(_ chunk: Int, fromCounterWithID objectIDstr: String) {
        if let index = transferCounters.firstIndex(where: {$0.uid == objectIDstr}) {
            transferCounters[index].chunksToSend.remove(chunk)
#if DEBUG
//            UploadManager.logger.notice("\(objectIDstr) • Remove chunk \(chunk) from counter")
#endif
        }
    }
    
    // Count how many bytes were sent
    func addBytes(_ bytes: Int64, toCounterWithID objectIDstr: String) -> Float {
        if let index = transferCounters.firstIndex(where: {$0.uid == objectIDstr}) {
            transferCounters[index].bytesSent += bytes
#if DEBUG
//            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: bytes)) ?? ""
//            UploadManager.logger.notice("\(objectIDstr) • Added \(value, privacy: .public) bytes to counter")
#endif
            return transferCounters[index].progress
        }
        else {
            var newCounter = TransferCounter(identifier: objectIDstr)
            newCounter.bytesSent = bytes
            transferCounters.append(newCounter)
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: bytes)) ?? ""
            UploadManager.logger.notice("\(objectIDstr) • Reinitialise counter with \(value, privacy: .public) bytes uploaded")
#endif
            return 0.1
        }
    }
        
    // Deallocate a counter upon upload completion
    func removeCounter(withID objectIDstr: String) {
        if let index = transferCounters.firstIndex(where: {$0.uid == objectIDstr}) {
            transferCounters.remove(at: index)
#if DEBUG
            UploadManager.logger.notice("\(objectIDstr) | Removed counter")
#endif
        }
    }
}
