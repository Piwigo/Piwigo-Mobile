//
//  UploadManager+Counter.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 23/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

extension UploadManager {
    
    struct UploadCounter {
        var uid: String
        var bytesSent: Int64        // Bytes sent
        var totalBytes: Int64       // Bytes to upload
        var progress: Float {       // Overall progress fraction
            get {
                return min(Float(bytesSent) / Float(totalBytes), 1.0)
            }
        }
        
        init(identifier: String, totalBytes: Int64 = 0) {
            self.uid = identifier
            self.bytesSent = Int64.zero
            self.totalBytes = totalBytes
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.uid == rhs.uid
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(uid)
        }
    }
    
    // Initialise a counter before resuming upload tasks
    func initCounter(withID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].bytesSent = Int64.zero
            uploadCounters[index].totalBytes = Int64.zero
#if DEBUG
            UploadManager.logger.notice("\(identifier, privacy: .public) • Did reset byte counts for counter")
#endif
        }
        else {
            let newCounter = UploadCounter(identifier: identifier)
            uploadCounters.append(newCounter)
#if DEBUG
            UploadManager.logger.notice("\(identifier, privacy: .public) • Initialised counter")
#endif
        }
    }
    
    // Set total nymber of bytes to upload
    func setTotalBytes(_ totalBytes: Int64, forCounterWithID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].totalBytes = totalBytes
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: totalBytes)) ?? ""
            UploadManager.logger.notice("\(identifier, privacy: .public) • Did set totalBytes of counter to \(value, privacy: .public) bytes")
#endif
        }
        else {  // Situation where the app was relauched
            var newCounter = UploadCounter(identifier: identifier)
            newCounter.totalBytes = totalBytes
            uploadCounters.append(newCounter)
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: totalBytes)) ?? ""
            UploadManager.logger.notice("\(identifier, privacy: .public) • Reinitialised counter with \(value, privacy: .public) total bytes")
#endif
        }
    }
    
    // Count how many bytes were sent
    func addBytes(_ bytes: Int64, toCounterWithID identifier: String) {
        if let index = uploadCounters.firstIndex(where: {$0.uid == identifier}) {
            uploadCounters[index].bytesSent += bytes
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: bytes)) ?? ""
            UploadManager.logger.notice("\(identifier, privacy: .public) • Added \(value, privacy: .public) bytes to counter")
#endif
        }
        else {
            var newCounter = UploadCounter(identifier: identifier)
            newCounter.bytesSent = bytes
            uploadCounters.append(newCounter)
#if DEBUG
            let value = UploadSessionsDelegate.bytesFormatter.string(from: NSNumber(value: bytes)) ?? ""
            UploadManager.logger.notice("\(identifier, privacy: .public) • Reinitialised counter with \(value, privacy: .public) bytes uploaded")
#endif
            debugPrint("[UploadManager] Initialised counter for \(identifier)")
        }
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
#if DEBUG
            UploadManager.logger.notice("\(identifier, privacy: .public) | Removed counter")
#endif
        }
    }
}
