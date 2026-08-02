//
//  ImageDownloader.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation
import PwgKit

public actor ImageDownloader {
    
    // Logs networking activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = PwgLogger(subsystem: "org.piwigo.apiKit", category: String(describing: ImageDownloader.self))
    
    // Singleton
    public static let shared = ImageDownloader()
    
    // Accepted image, video and PDF types
    let acceptedTypes: String = {
        // Image types
        var mimeTypes = acceptedImageTypes.compactMap {$0.tags[.mimeType]}.flatMap({$0})

        // Add movie and PDF types for full-resolution downloads
        mimeTypes += acceptedMovieTypes.compactMap {$0.tags[.mimeType]}.flatMap({$0})
        mimeTypes.append("application/pdf")

        // Add text types for handling Piwigo errors and redirects
        mimeTypes += ["text/plain", "text/html"]
        return mimeTypes.joined(separator: ", ")
    }()
    // Maximum number of simultaneous downloads
    let maxConcurrentDownloads = 4
    // Enqueued and running downloads
    var downloads: [URL : ImageDownload] = [ : ]
    
    
    // MARK: - Create, Launch Downloads
    // Return image in cache or download it
    public func getImage(withID imageID: Int64?, ofSize imageSize: pwgImageSize, type: pwgImageType,
                         atURL imageURL: URL?, fromServer serverID: String?, fileSize: Int64 = NSURLSessionTransferSizeUnknown,
                         isPrefetch: Bool = false,
                         progress: ((Float) -> Void)? = nil,
                         completion: @escaping (URL) -> Void,
                         failure: @escaping (PwgKitError) -> Void) {
        // Check arguments
        guard let imageID, imageID != 0,
              let imageURL, imageURL.isFileURL == false,
              let serverID, serverID.isEmpty == false
        else {
            failure(.failedToPrepareDownload)
            return
        }
        
//        #if DEBUG
//        ImageDownloader.logger.notice("Get image \(imageID) of size \(imageSize.name)")
//        #endif
        
        // Determine URL of image in cache
        let cacheDir = DataDirectories.cacheDirectory.appendingPathComponent(serverID)
        let fileURL = cacheDir.appendingPathComponent(imageSize.path)
            .appendingPathComponent(String(imageID))
        
        // Do we already have this image or video in cache?
        let cachedFileSize = fileURL.fileSize
        if cachedFileSize > 0 {
            // We do have an image in cache, but is this the image or expected video?
            var isExpectedFile = true
            if imageSize == .fullRes {
                let diff = abs((Double(cachedFileSize) - Double(fileSize)) / Double(fileSize))
//                debugPrint("••> Image \(fileURL.lastPathComponent): \((diff * 1000).rounded(.awayFromZero)/10)%) retrieved from cache.")
                isExpectedFile = diff < 0.1     // i.e. 10%
            }
            if isExpectedFile {
//                #if DEBUG
//                ImageDownloader.logger.notice("Return cached image \(fileURL.lastPathComponent) downloaded from \(imageURL)")
//                #endif
                // The file may have just been stored in cache by a download whose task
                // did not complete yet. Its handlers must then be called, not discarded.
                if let download = downloads[imageURL],
                   download.task?.state != .running, download.task?.state != .suspended {
                    if isPrefetch == false {
                        download.addHandlers(progress: progress, completion: completion, failure: failure)
                    }
                    completeDownload(download, for: imageURL)
                }
                else if isPrefetch == false {
                    complete(with: completion, fileURL: fileURL)
                }
                return
            }
        }
        
        // Already existing download instance?
        let runningDownloads: Int = downloads.values.filter({ $0.task?.state == .running }).count
        if let download = downloads[imageURL]
        {
            // Add the handlers of this view so that it also gets the callbacks
            if isPrefetch == false {
                #if DEBUG
                ImageDownloader.logger.notice("Add handlers to download of \(fileURL.lastPathComponent)")
                #endif
                download.addHandlers(progress: progress, completion: completion, failure: failure)
            }
            
            // Already existing task?
            if let task = download.task {
                switch task.state {
                case .running:
                    progress?(download.progress)
                    return

                case .suspended:
                    guard runningDownloads < maxConcurrentDownloads
                    else { return }
                    
                    #if DEBUG
                    ImageDownloader.logger.notice("Resume suspended download of \(fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
                    #endif
                    download.isCancelled = false
                    task.resume()
                    return
                
                case .completed:
                    // The task did complete but the file is not in cache yet (checked above)
                    // ► the delegate will store it and call the handlers of all views
                    #if DEBUG
                    ImageDownloader.logger.notice("Wait for the completion of the download of \(fileURL.lastPathComponent)")
                    #endif
                    return

                default:
                    guard runningDownloads < maxConcurrentDownloads
                    else { return }
                    
                    // Resume download task w/ data if possible
                    if let resumeData = download.resumeData {
                        #if DEBUG
                        ImageDownloader.logger.notice("Resume download of \(fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
                        #endif
                        download.isCancelled = false
                        download.task = dataSession.downloadTask(withResumeData: resumeData)
                        download.task?.resume()
                        return
                    }
                    
                    // Resume download w/o data if possible
                    download.isCancelled = false
                    if runningDownloads < maxConcurrentDownloads {
                        launchDownload(download)
                    }
                    return
                }
            }
            
            // No download task
            download.isCancelled = false
            if runningDownloads < maxConcurrentDownloads {
                launchDownload(download)
            }
            return
        }
        
        // Create a new download instance
        let download = ImageDownload(type: type, atURL: imageURL, fileSize: fileSize, toCacheAt: fileURL,
                                     progress: progress, completion: completion, failure: failure)
        downloads[imageURL] = download
        
        // Launch image download if possible
        if runningDownloads < maxConcurrentDownloads {
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
        download.task?.taskDescription = imageURL.absoluteString
        download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        download.task?.countOfBytesClientExpectsToReceive = download.fileSize
        download.task?.resume()
        
        // Keep download instance in memory
        #if DEBUG
        let runningDownloads: Int = downloads.values.filter({ $0.task?.state == .running }).count
        ImageDownloader.logger.notice("Task #\(download.task?.taskIdentifier ?? -1) created to download image #\(download.fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
        #endif
    }
    
    
    // MARK: - Pause, Cancel Downloads
    public func pauseDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = downloads[imageURL]
        else { return }
        
        // Cancel the download request
        guard let task = download.task
        else { return }
        switch task.state {
        case .running, .suspended:
            task.cancel { data in
                if let data {
                    #if DEBUG
                    ImageDownloader.logger.notice("Pause download of \(download.fileURL.lastPathComponent) with resume data")
                    #endif
                    download.resumeData = data
                    download.isCancelled = true
                } else {
                    #if DEBUG
                    ImageDownloader.logger.notice("Cancel download of \(download.fileURL.lastPathComponent) without resume data")
                    #endif
                    download.task?.cancel()
                    download.task = nil
                    download.isCancelled = true
                }
            }
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
        guard let download = downloads[imageURL]
        else { return }
        
        // Cancel the download request
        #if DEBUG
        let runningDownloads: Int = downloads.values.filter({ $0.task?.state == .running }).count
        ImageDownloader.logger.notice("Cancel download of \(download.fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
        #endif
        download.isCancelled = true
        
        if let task = download.task {
            switch task.state {
            case .running, .suspended, .canceling:
                task.cancel()
                download.task = nil
            default:
                downloads.removeValue(forKey: imageURL)
            }
        } else {
            downloads.removeValue(forKey: imageURL)
       }
    }
    
    public func cancelAll() {
        // Cancel every active network task.
        downloads.values.forEach {
            $0.isCancelled = true
            $0.task?.cancel()
        }
        downloads.removeAll()
    }
    
    
    // MARK: - Accessors called from PwgSessionDelegate
    func download(for imageURL: URL) -> ImageDownload? {
        downloads[imageURL]
    }
    
    func updateProgress(_ progress: Float, for imageURL: URL) {
        guard let download = downloads[imageURL]
        else { return }
        download.progress = progress
        download.progressHandlers.forEach { $0(progress) }
    }
    
    func storeAndComplete(tempFile: URL, for imageURL: URL) {
        guard let download = downloads[imageURL],
              let fileURL = download.fileURL
        else {
            try? FileManager.default.removeItem(at: tempFile)
            return
        }
        storeDownloadedFile(from: tempFile, to: fileURL, forImageURL: imageURL)
        try? FileManager.default.removeItem(at: tempFile)
//        #if DEBUG
//        ImageDownloader.logger.notice("Downloaded file of \(download.fileURL.lastPathComponent) stored in cache")
//        #endif
    }
    
    func completeDownloadIfReady(for imageURL: URL) {
        guard let download = downloads[imageURL]
        else { return }
//        #if DEBUG
//        ImageDownloader.logger.notice("Download of \(download.fileURL.lastPathComponent) completed")
//        #endif
        completeDownload(download, for: imageURL)
    }
    
    func failDownload(for imageURL: URL, error: PwgKitError) {
        guard let download = downloads[imageURL]
        else { return }
        if !download.isCancelled {
            download.failureHandlers.forEach { $0(error) }
        }
        downloads.removeValue(forKey: imageURL)

        // Next download?
        launchDownloadsIfAnyAndPossible()
    }


    // MARK: - Private helpers
    // Returns the image in cache to every view which did request it
    private func completeDownload(_ download: ImageDownload, for imageURL: URL) {
        guard let fileURL = download.fileURL
        else { return }
//        #if DEBUG
//        ImageDownloader.logger.notice("Calling \(download.completionHandlers.count) completion handler(s) for \(fileURL.lastPathComponent)")
//        #endif
        download.completionHandlers.forEach { complete(with: $0, fileURL: fileURL) }
        downloads.removeValue(forKey: imageURL)

        // Next downloads?
        launchDownloadsIfAnyAndPossible()
    }
    
    // Completion handlers may perform heavy work such as image decoding,
    // so they are called outside the actor to avoid serialising all cache checks,
    // downloads and completions behind each decode.
    private nonisolated func complete(with completionHandler: ((URL) -> Void)?, fileURL: URL) {
        guard let completionHandler else { return }
        Task.detached(priority: .userInitiated) {
            completionHandler(fileURL)
        }
    }

    private func storeDownloadedFile(from location: URL, to fileURL: URL, forImageURL imageURL: URL) {
        do {
            let fm = FileManager.default
            let dirURL = fileURL.deletingLastPathComponent()
            if fm.fileExists(atPath: dirURL.path) == false {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
            try? fm.removeItem(at: fileURL)
            try fm.copyItem(at: location, to: fileURL)
        }
        catch {
            failDownload(for: imageURL, error: .otherError(innerError: error))
        }
    }
    
    private func launchDownloadsIfAnyAndPossible() {
        var runningDownloads: Int = downloads.values.filter({ $0.task?.state == .running }).count
        for (_, download) in downloads {
            // Max number of tasks reached?
            if runningDownloads >= maxConcurrentDownloads {
                #if DEBUG
                ImageDownloader.logger.notice("Max concurrent downloads reached: postpone download of \(download.fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
                #endif
                break
            }
            
            // Cancelled?
            guard download.isCancelled == false
            else { continue }
            
            // Already existing task?
            if let task = download.task {
                switch task.state {
                case .running:
                    download.progressHandlers.forEach { $0(download.progress) }
                    continue

                case .suspended:
                    #if DEBUG
                    ImageDownloader.logger.notice("Resume suspended download of \(download.fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
                    #endif
                    runningDownloads += 1
                    task.resume()
                    continue
                
                case .completed:
                    continue
                
                default:
                    // Resume download task w/ data if possible
                    if let resumeData = download.resumeData {
                        #if DEBUG
                        ImageDownloader.logger.notice("Resume download of \(download.fileURL.lastPathComponent) (\(runningDownloads)/\(self.maxConcurrentDownloads) running, \(self.downloads.count - runningDownloads) waiting)")
                        #endif
                        runningDownloads += 1
                        download.task = dataSession.downloadTask(withResumeData: resumeData)
                        download.task?.resume()
                        continue
                    }
                    
                    // Resume download w/o data if possible
                    if runningDownloads < maxConcurrentDownloads {
                        runningDownloads += 1
                        launchDownload(download)
                    }
                    continue
                }
            }
            
            // No download task
            runningDownloads += 1
            launchDownload(download)
        }
    }
}
