//
//  PwgSessionDelegate+Task.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import Foundation

// MARK: - Session Task Delegate
extension PwgSessionDelegate: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        // Retrieve the original URL of this task
        guard let imageURL = imageURL(fromTask: task)
        else { return }
        
        // Manage the error type
        var pwgError: PwgKitError?
        if let error = error as? URLError {
            pwgError = .requestFailed(innerError: error)
        }
        else if let error = error as? DecodingError {
            pwgError = .decodingFailed(innerError: error)
        }
        else if let response = task.response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) == false {
            pwgError = .invalidStatusCode(statusCode: response.statusCode)
        }
        else if let error = error {
            pwgError = .otherError(innerError: error)
        }
        
        // Handle the response with the Download Manager
        Task {
            if let pwgError {
                // Return error with failureHandler
                PwgSessionDelegate.logger.notice("Did complete task #\(task.taskIdentifier, privacy: .public) with error: \(pwgError.localizedDescription)")
                await ImageDownloader.shared.failDownload(for: imageURL, error: pwgError)
            }
            else {
                // Return cached image with completionHandler
                PwgSessionDelegate.logger.notice("Did complete task #\(task.taskIdentifier, privacy: .public)")
                await ImageDownloader.shared.completeDownloadIfReady(for: imageURL)
            }
        }
    }
}


// MARK: - Session Download Delegate
extension PwgSessionDelegate: URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        // Retrieve the original URL of this task
//        #if DEBUG
//        PwgSessionDelegate.logger.notice("Progress task #\(downloadTask.taskIdentifier, privacy: .public): \(totalBytesWritten, privacy: .public) total bytes downloaded from \(downloadTask.taskDescription ?? "<unknown>")")
//        #endif
        guard let imageURL = imageURL(fromTask: downloadTask)
        else { return }
        
        // Update progress bar if any
        let progress: Float
        if totalBytesExpectedToWrite > 0 {
            progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        } else {
            progress = 1.0 - Float(bytesWritten) / Float(totalBytesWritten)
        }
        Task { await ImageDownloader.shared.updateProgress(progress, for: imageURL) }
//        #if DEBUG
//        PwgSessionDelegate.logger.notice("Progress task #\(downloadTask.taskIdentifier, privacy: .public) -> written: \(bytesWritten, privacy: .public), totalWritten: \(totalBytesWritten, privacy: .public), expected: \(totalBytesExpectedToWrite, privacy: .public), progress: \(progress, privacy: .public)")
//        #endif
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        // Retrieve the URL of this task
        #if DEBUG
        PwgSessionDelegate.logger.notice("Task #\(downloadTask.taskIdentifier, privacy: .public) did finish downloading to \(location, privacy: .public)")
        #endif
        guard let imageURL = imageURL(fromTask: downloadTask)
        else { return }
        
        // Copy the temp file synchronously before URLSession deletes it
        // then hand off the final URL to the actor.
        let tempCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: location, to: tempCopy)
        }
        catch {
            Task { await ImageDownloader.shared.failDownload(for: imageURL, error: .otherError(innerError: error)) }
            return
        }
        Task { await ImageDownloader.shared.storeAndComplete(tempFile: tempCopy, for: imageURL) }
    }
}
