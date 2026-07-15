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
                    downloads.removeValue(forKey: imageURL)
                    completion(fileURL)
                    return
                }
            } else {
//                debugPrint("••> return cached image \(String(describing: download.fileURL.lastPathComponent)) i.e., downloaded from \(imageURL)")
                downloads.removeValue(forKey: imageURL)
                completion(fileURL)
                return
            }
        }
        
        // Already existing download instance?
        let runningDownloads: Int = downloads.values.filter({ $0.task?.state == .running }).count
        if let download = downloads[imageURL]
        {
            // Refresh handlers so the new visible cell gets the callbacks
            download.progressHandler = progress
            download.completionHandler = completion
            download.failureHandler = failure
            
            // Already existing task?
            if let task = download.task {
                switch task.state {
                case .running:
                    download.progressHandler?(download.progress)
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
                    #if DEBUG
                    ImageDownloader.logger.notice("Delete completed download of \(fileURL.lastPathComponent)")
                    #endif
                    downloads[imageURL] = nil
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
        download.progressHandler?(progress)
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
    }
    
    func completeDownloadIfReady(for imageURL: URL) {
        guard let download = downloads[imageURL],
              let fileURL = download.fileURL
        else { return }
        download.completionHandler?(fileURL)
        downloads.removeValue(forKey: imageURL)
        
        // Next downloads?
        launchDownloadsIfAnyAndPossible()
    }
    
    func failDownload(for imageURL: URL, error: PwgKitError) {
        guard let download = downloads[imageURL]
        else { return }
        if !download.isCancelled {
            download.failureHandler?(error)
        }
        downloads.removeValue(forKey: imageURL)
        
        // Next download?
        launchDownloadsIfAnyAndPossible()
    }
    
    
    // MARK: - Private helpers
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
                break
            }
            
            // Cancelled?
            guard download.isCancelled == false
            else { continue }
            
            // Already existing task?
            if let task = download.task {
                switch task.state {
                case .running:
                    download.progressHandler?(download.progress)
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
