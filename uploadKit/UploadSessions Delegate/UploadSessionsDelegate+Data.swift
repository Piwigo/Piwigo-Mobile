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
#if DEBUG
        let dataStr = String(decoding: data, as: UTF8.self)
        UploadSessionsDelegate.logger.notice("\(objectURIstr) • Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) did receive: \(dataStr, privacy: .public).")
#else
        let countsOfBytes = data.count * MemoryLayout<Data>.stride
        UploadSessions.logger.notice("\(objectURIstr) • Task \(dataTask.taskIdentifier, privacy: .public) of chunk \(chunk+1, privacy: .public)/\(chunks, privacy: .public) did receive \(countsOfBytes, privacy: .public) bytes.")
#endif

        let sessionIdentifier = taskDescription.components(separatedBy: " ").first
        switch sessionIdentifier {
        case uploadSessionIdentifier:
            Task { @UploadManagerActor in
                UploadManager.shared.didCompleteUploadTask(dataTask, withData: data)
            }
        case uploadBckgSessionIdentifier:
            Task { @UploadManagerActor in
                UploadManager.shared.didCompleteBckgUploadTask(dataTask, withData: data)
            }
        default:
            UploadSessionsDelegate.logger.fault("Unexpected session identifier.")
            preconditionFailure("Unexpected session identifier.")
        }
    }
}
