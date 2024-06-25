//
//  PwgSession+Image.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Download Image
extension PwgSession
{
    public func getImage(withID imageID: Int64?, ofSize imageSize: pwgImageSize, atURL imageURL: URL?,
                         fromServer serverID: String?, fileSize: Int64 = NSURLSessionTransferSizeUnknown,
                         placeHolder: UIImage, progress: ((Float) -> Void)? = nil,
                         completion: @escaping (URL) -> Void, failure: @escaping (Error) -> Void) {
        // Check arguments
        guard let imageID = imageID, imageID != 0,
              let imageURL = imageURL, imageURL.isFileURL == false,
              let serverID = serverID, serverID.isEmpty == false
        else {
            let error = NSError(domain: "Piwigo", code: PwgSessionError.failedToPrepareDownload.hashValue,
                        userInfo: [NSLocalizedDescriptionKey : PwgSessionError.failedToPrepareDownload.localizedDescription])
            failure(error)
            return
        }
        
        // Create the download request
        var request = URLRequest(url: imageURL)
        request.addValue(acceptedTypes, forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        // Create Download instance
        let download = ImageDownload(imageID: imageID, ofSize: imageSize, atURL: imageURL,
                                     fromServer: serverID, fileSize: fileSize, placeHolder: placeHolder,
                                     progress: progress, completion: completion, failure: failure)

        // Do we already have this image or video in cache?
        if download.fileURL.fileSize > 0 {
            // We do have an image in cache, but is this the image or expected video?
            if imageSize == .fullRes {
                let cachedFileSize = download.fileURL.fileSize
                let diff = abs((Double(cachedFileSize) - Double(fileSize)) / Double(fileSize))
//                print("••> Image \(download.fileURL.lastPathComponent) of \(cachedFileSize) bytes (\((diff * 1000).rounded(.awayFromZero)/10)%) retrieved from cache.")
                if diff < 0.1 {     // i.e. 10%
                    completion(download.fileURL)
                    return
                }
            } else {
//            debugPrint("••> return cached image \(String(describing: download.fileURL.lastPathComponent)) i.e., downloaded from \(imageURL)")
                completion(download.fileURL)
                return
            }
        }

        // Download this image in the background thread
        guard let download = self.activeDownloads[imageURL] else {
//            debugPrint("••> Launch download of image: \(imageURL)")
            download.task = self.dataSession.downloadTask(with: request)
            download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
            download.task?.countOfBytesClientExpectsToReceive = download.fileSize
            download.task?.resume()
            self.activeDownloads[imageURL] = download
            return
        }
        
        // Resume download
//        debugPrint("••> Resume download of image: \(imageURL)")
        download.progressHandler = progress
        if let progressHandler = download.progressHandler {
            progressHandler(download.progress)
        }
        download.completionHandler = completion
        download.failureHandler = failure
        if let resumeData = download.resumeData {
            download.task = self.dataSession.downloadTask(withResumeData: resumeData)
        } else {
            download.task = self.dataSession.downloadTask(with: request)
        }
        download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        download.task?.countOfBytesClientExpectsToReceive = download.fileSize
        download.task?.resume()
        self.activeDownloads[imageURL] = download
    }
    
    public func pauseDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = activeDownloads[imageURL] else {
            return
        }
        
        // Cancel the download request
        download.task?.cancel(byProducingResumeData: { imageData in
//            debugPrint("••> Pause download: \(imageURL)")
            download.resumeData = imageData
        })
    }
    
    public func cancelDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = activeDownloads[imageURL] else {
            return
        }

        // Cancel the download request
//        debugPrint("••> Cancel download: \(imageURL)")
        activeDownloads.removeValue(forKey: imageURL)
        download.task?.cancel()
    }
}

// MARK: - Session
extension PwgSession: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Retrieve the original URL of this task
//        debugPrint("••> Did complete task #\(task.taskIdentifier) with error: \(error?.localizedDescription ?? "none")")
        guard let imageURL = task.originalRequest?.url ?? task.currentRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        if let error = error {
            // Remove task from active downloads if needed
            if download.resumeData == nil {
                activeDownloads.removeValue(forKey: imageURL)
            }
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(error)
            }
        } else {
            // Remove task from active downloads
            activeDownloads.removeValue(forKey: imageURL)
            // Return cached image with completionHandler
            if let completion = download.completionHandler,
               let fileURL = download.fileURL {
                completion(fileURL)
            }
        }
    }
}


// MARK: - Session Download Delegate
extension PwgSession: URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        // Retrieve the original URL of this task
//        debugPrint("••> Progress task #\(downloadTask.taskIdentifier): \(totalBytesWritten) total bytes downloaded from \(String(describing: downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url))")
//        activeDownloads.forEach { (key, _) in debugPrint("   Key: \(key)") }
        guard let imageURL = downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        // Update progress bar if any
        if let progressHandler = download.progressHandler {
            download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
//            debugPrint("••> Progress task #\(downloadTask.taskIdentifier) -> written: \(bytesWritten), totalWritten: \(totalBytesWritten), expected: \(totalBytesExpectedToWrite), progress: \(download.progress)")
            progressHandler(download.progress)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Retrieve the URL of this task
//        debugPrint("••> Task #\(downloadTask.taskIdentifier) did finish downloading to \(location)")
        guard let imageURL = downloadTask.originalRequest?.url ?? downloadTask.currentRequest?.url,
              let download = activeDownloads[imageURL],
              let fileURL = download.fileURL else {
            return
        }

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
        } catch {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(error)
            }
        }
    }
}
