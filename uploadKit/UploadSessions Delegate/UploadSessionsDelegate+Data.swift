//
//  UploadSessionsDelegate+Data.swift
//  uploadKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Session Data Delegate
extension UploadSessionsDelegate: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
        // Get upload info from the task
        guard let objectURIstr = dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPuploadID),
              let chunkStr = dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunk), let chunk = Int(chunkStr),
              let chunksStr = dataTask.originalRequest?.value(forHTTPHeaderField: pwgHTTPchunks), let chunks = Int(chunksStr),
              let taskDescription = dataTask.taskDescription
        else {
            UploadSessionsDelegate.logger.notice("Could not extract HTTP header fields.")
            preconditionFailure("Could not extract HTTP header fields.")
        }

        // Log data task
        let objectIDstr = URL(string: objectURIstr)?.lastPathComponent ?? objectURIstr
#if DEBUG
        let dataStr = String(decoding: data.prefix(100), as: UTF8.self) + (data.count > 100 ? "…" : "")
        UploadSessionsDelegate.logger.notice("\(objectIDstr, privacy: .public) • Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk, privacy: .public)/\(chunks, privacy: .public) did receive: \(dataStr, privacy: .public).")
#else
        let countsOfBytes = data.count * MemoryLayout<Data>.stride
        UploadSessionsDelegate.logger.notice("\(objectIDstr, privacy: .public) • Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk, privacy: .public)/\(chunks, privacy: .public) did receive \(countsOfBytes, privacy: .public) bytes.")
#endif

        let sessionIdentifier = taskDescription.components(separatedBy: " ").first
        switch sessionIdentifier {
        case uploadBckgSessionIdentifier:
            Task(priority: .utility) { @UploadManagerActor in
                await UploadManager.shared.didCompleteBckgUploadTask(dataTask, withData: data)
            }
        default:
            preconditionFailure("Unexpected session identifier.")
        }
    }
}
