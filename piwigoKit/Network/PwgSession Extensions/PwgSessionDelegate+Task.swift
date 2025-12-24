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
//        debugPrint("••> Did complete task #\(task.taskIdentifier) with error: \(error?.localizedDescription ?? "none")")
        guard let imageURL = task.originalRequest?.url ?? task.currentRequest?.url,
              let download = PwgSessionDelegate.activeDownloads[imageURL]
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
        if let pwgError {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(pwgError)
            }
        } else {
            // Return cached image with completionHandler
            if let completion = download.completionHandler,
               let fileURL = download.fileURL {
                completion(fileURL)
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
//        debugPrint("••> Progress task #\(downloadTask.taskIdentifier): \(totalBytesWritten) total bytes downloaded from \(String(describing: downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url))")
//        activeDownloads.forEach { (key, _) in debugPrint("   Key: \(key)") }
        guard let imageURL = downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url,
              let download = PwgSessionDelegate.activeDownloads[imageURL]
        else { return }

        // Update progress bar if any
        if let progressHandler = download.progressHandler {
            if totalBytesExpectedToWrite > 0 {
                download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
//                debugPrint("••> Progress task #\(downloadTask.taskIdentifier) -> written: \(bytesWritten), totalWritten: \(totalBytesWritten), expected: \(totalBytesExpectedToWrite), progress: \(download.progress)")
            } else {
                download.progress = 1.0 - Float(bytesWritten) / Float(totalBytesWritten)
//                debugPrint("••> Progress task #\(downloadTask.taskIdentifier) -> written: \(bytesWritten), totalWritten: \(totalBytesWritten), expected: \(totalBytesExpectedToWrite), progress: \(download.progress)")
            }
            progressHandler(download.progress)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Retrieve the URL of this task
//        debugPrint("••> Task #\(downloadTask.taskIdentifier) did finish downloading to \(location)")
        guard let imageURL = downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url,
              let download = PwgSessionDelegate.activeDownloads[imageURL],
              let fileURL = download.fileURL
        else { return }

        // Create parent directories if needed
        do {
            let fm = FileManager.default
            let dirURL = fileURL.deletingLastPathComponent()
            if fm.fileExists(atPath: dirURL.path) == false {
//                debugPrint("••> Create directory \(dirURL.path)")
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true,
                                       attributes: nil)
            }
            
            // Delete existing file if it exists (incomplete previous attempt?)
            try? fm.removeItem(at: fileURL)
    
            // Store image
            try fm.copyItem(at: location, to: fileURL)
//            debugPrint("••> Image \(fileURL.lastPathComponent) stored in cache (URL: \(imageURL)")
        }
        catch {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(PwgKitError.otherError(innerError: error))
            }
        }
    }
}
