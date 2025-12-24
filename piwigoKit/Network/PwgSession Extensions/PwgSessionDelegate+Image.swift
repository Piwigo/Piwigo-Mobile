//
//  PwgSessionDelegate+Image.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/05/2024.
//  Copyright © 2024 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Download Image
extension PwgSessionDelegate
{
    public func getImage(withID imageID: Int64?, ofSize imageSize: pwgImageSize, type: pwgImageType,
                         atURL imageURL: URL?, fromServer serverID: String?, fileSize: Int64 = NSURLSessionTransferSizeUnknown,
                         progress: ((Float) -> Void)? = nil, completion: @escaping (URL) -> Void, failure: @escaping (PwgKitError) -> Void) {
        // Check arguments
        guard let imageID = imageID, imageID != 0,
              let imageURL = imageURL, imageURL.isFileURL == false,
              let serverID = serverID, serverID.isEmpty == false
        else {
            failure(.failedToPrepareDownload)
            return
        }
        
        // Determine URL of image in cache
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        let fileURL = cacheDir.appendingPathComponent(imageSize.path)
            .appendingPathComponent(String(imageID))

        // Do we already have this image or video in cache?
        let cachedFileSize = fileURL.fileSize
//        debugPrint("••> Image \(fileURL.lastPathComponent) of \(cachedFileSize) bytes")
        if cachedFileSize > 0 {
            // We do have an image in cache, but is this the image or expected video?
            if imageSize == .fullRes {
                let diff = abs((Double(cachedFileSize) - Double(fileSize)) / Double(fileSize))
//                debugPrint("••> Image \(fileURL.lastPathComponent): \((diff * 1000).rounded(.awayFromZero)/10)%) retrieved from cache.")
                if diff < 0.1 {     // i.e. 10%
                    PwgSessionDelegate.activeDownloads.removeValue(forKey: imageURL)
                    completion(fileURL)
                    return
                }
            } else {
//                debugPrint("••> return cached image \(String(describing: download.fileURL.lastPathComponent)) i.e., downloaded from \(imageURL)")
                PwgSessionDelegate.activeDownloads.removeValue(forKey: imageURL)
                completion(fileURL)
                return
            }
        }
        
        // Does this download instance already exist?
        guard let download = PwgSessionDelegate.activeDownloads[imageURL]
        else {
            // Create Download instance
            let download = ImageDownload(type: type, atURL: imageURL, fileSize: fileSize, toCacheAt: fileURL,
                                         progress: progress, completion: completion, failure: failure)
            // Launch image download
            launchDownload(download)
            return
        }
        
        // Update handlers
        download.progressHandler = progress
        download.completionHandler = completion
        download.failureHandler = failure
        
        // What should we do with this download instance?
        if let task = download.task {
            switch task.state {
            case .running:
                if let progressHandler = download.progressHandler {
                    progressHandler(download.progress)
                }
            case .suspended:
                #if DEBUG
                PwgSessionDelegate.logger.notice("Resume suspended download of image \(fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
                #endif
                task.resume()
            case .completed:
                #if DEBUG
                PwgSessionDelegate.logger.notice("Delete download instance of image \(fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
                #endif
                PwgSessionDelegate.activeDownloads[imageURL] = nil
            default:
                if let resumeData = download.resumeData {
                    #if DEBUG
                    PwgSessionDelegate.logger.notice("Resume download of image \(fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
                    #endif
                    download.task = dataSession.downloadTask(withResumeData: resumeData)
                } else {
                    #if DEBUG
                    PwgSessionDelegate.logger.notice("Relaunch download of image \(fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
                    #endif
                    launchDownload(download)
                }
            }
        } else {
            #if DEBUG
            PwgSessionDelegate.logger.notice("Relaunch download of image \(fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
            #endif
            launchDownload(download)
        }
    }
    
    private func launchDownload(_ download: ImageDownload) {
        // Check provided image URL
        guard let imageURL = download.imageURL
        else { preconditionFailure("Image URL not provided before download")}
        
        // Create the download request
        var request = URLRequest(url: imageURL)
        request.addValue(acceptedTypes, forHTTPHeaderField: "Accept")
        request.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        // Create and resume download task
        download.task = dataSession.downloadTask(with: request)
        download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        download.task?.countOfBytesClientExpectsToReceive = download.fileSize
        download.task?.resume()
        
        // Keep download instance in memory
        PwgSessionDelegate.activeDownloads[imageURL] = download
//        #if DEBUG
//        PwgSessionDelegate.logger.notice("Launch download of image \(download.fileURL.lastPathComponent) (\(self.activeDownloads.count) active downloads)")
//        #endif
    }
    
    public func pauseDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = PwgSessionDelegate.activeDownloads[imageURL]
        else { return }
        
        // Cancel the download request
        guard let task = download.task else { return }
        switch task.state {
        case .running, .suspended:
            download.task?.cancel(byProducingResumeData: { data in
                if let data = data {
#if DEBUG
                    PwgSessionDelegate.logger.notice("Pause download of image \(download.fileURL.lastPathComponent) with resume data (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
#endif
                    download.resumeData = data
                } else {
#if DEBUG
                    PwgSessionDelegate.logger.notice("Cancel download of image \(download.fileURL.lastPathComponent) without resume data (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
#endif
                    download.task?.cancel()
                    download.task = nil
                }
            })
        case .canceling:
            break
        case .completed:
            download.task = nil
        default:
            return
        }
    }
    
    public func cancelDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = PwgSessionDelegate.activeDownloads[imageURL]
        else { return }

        // Cancel the download request
        #if DEBUG
        PwgSessionDelegate.logger.notice("Cancel download of image \(download.fileURL.lastPathComponent) (\(PwgSessionDelegate.activeDownloads.count) active downloads)")
        #endif
        download.task?.cancel()
        download.task = nil
    }
}

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
