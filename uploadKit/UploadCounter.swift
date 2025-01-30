//
//  UploadCounter.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 08/01/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Counter for Updating Progress Bars and Managing Tasks
// Upload counters kept in memory during upload
struct UploadCounter {
    var uid: String
    var bytesSent: Int64        // Bytes sent
    var totalBytes: Int64       // Bytes to upload
    var chunks: Set<Int>        // Chunk IDs of resumed tasks
    var progress: Float {
        get {
            return min(Float(bytesSent) / Float(totalBytes), 1.0)
        }
    }
    
    init(identifier: String, totalBytes: Int64 = 0) {
        self.uid = identifier
        self.bytesSent = Int64.zero
        self.totalBytes = totalBytes
        self.chunks = Set<Int>()
    }
}

extension UploadCounter: Hashable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

extension UploadSessions {
    // Initialise a counter before resuming upload tasks
    func initCounter(withID identifier: String, totalBytes: Int64 = 0) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].totalBytes = totalBytes
        }
        else {
            let newCounter = UploadCounter(identifier: identifier, totalBytes: totalBytes)
            uploadCounters.append(newCounter)
        }
    }
    
    // Count how many bytes were sent
    func addBytes(_ bytes: Int64, toCounterWithID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].bytesSent += bytes
        }
        else {
            var newCounter = UploadCounter(identifier: identifier)
            newCounter.bytesSent = bytes
            uploadCounters.append(newCounter)
        }
    }

    // Remember which chunks were managed
    func addChunk(_ chunk: Int, toCounterWithID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].chunks.insert(chunk)
        }
        else {
            var newCounter = UploadCounter(identifier: identifier)
            newCounter.chunks.insert(chunk)
            uploadCounters.append(newCounter)
        }
    }
    
    // Return chunks already managed
    func getChunks(forCounterWithID identifier: String) -> Set<Int> {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            return uploadCounters[index].chunks
        }
        return Set<Int>()
    }
    
    // Returns progress value
    func getProgress(forCounterWithID identifier: String) -> Float {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            return uploadCounters[index].progress
        }
        return Float.zero
    }
    
    // Deallocate a counter upon upload completion
    func removeCounter(withID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters.remove(at: index)
        }
    }
}
