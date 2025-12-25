//
//  ImageDownloader.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/12/2025.
//  Copyright © 2025 Piwigo.org. All rights reserved.
//

import os
import Foundation

public final class ImageDownloader {
    
    // Logs networking activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: String(describing: ImageDownloader.self))
    
    // Singleton
    public static let shared = ImageDownloader()
    
    // Active downloads
    static var activeDownloads: [URL : ImageDownload] = [ : ]
    
    // Return image in cache or download it
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
                    ImageDownloader.activeDownloads.removeValue(forKey: imageURL)
                    completion(fileURL)
                    return
                }
            } else {
//                debugPrint("••> return cached image \(String(describing: download.fileURL.lastPathComponent)) i.e., downloaded from \(imageURL)")
                ImageDownloader.activeDownloads.removeValue(forKey: imageURL)
                completion(fileURL)
                return
            }
        }
        
        // Does this download instance already exist?
        if let download = ImageDownloader.activeDownloads[imageURL] {
            // Update handlers
            download.progressHandler = progress
            
            // What should we do with this download instance?
            if let task = download.task {
                switch task.state {
                case .running:
                    if let progressHandler = download.progressHandler {
                        progressHandler(download.progress)
                    }
                case .suspended:
                    #if DEBUG
                    ImageDownloader.logger.notice("Resume suspended download of image \(fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
                    #endif
                    task.resume()
                case .completed:
                    #if DEBUG
                    ImageDownloader.logger.notice("Delete download instance of image \(fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
                    #endif
                    ImageDownloader.activeDownloads[imageURL] = nil
                default:
                    if let resumeData = download.resumeData {
                        #if DEBUG
                        ImageDownloader.logger.notice("Resume download of image \(fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
                        #endif
                        download.task = dataSession.downloadTask(withResumeData: resumeData)
                        task.resume()
                    } else {
                        #if DEBUG
                        ImageDownloader.logger.notice("Relaunch download of image \(fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
                        #endif
                        launchDownload(download)
                    }
                }
            } else {
                #if DEBUG
                ImageDownloader.logger.notice("Relaunch download of image \(fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
                #endif
                launchDownload(download)
            }
        }
        else {
            // Create Download instance
            let download = ImageDownload(type: type, atURL: imageURL, fileSize: fileSize, toCacheAt: fileURL,
                                         progress: progress, completion: completion, failure: failure)
            // Launch image download
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
        ImageDownloader.activeDownloads[imageURL] = download
#if DEBUG
        ImageDownloader.logger.notice("Launch download of image \(download.fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
#endif
    }
    
    public func pauseDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = ImageDownloader.activeDownloads[imageURL]
        else { return }
        
        // Cancel the download request
        guard let task = download.task else { return }
        switch task.state {
        case .running, .suspended:
            download.task?.cancel(byProducingResumeData: { data in
                if let data = data {
#if DEBUG
                    ImageDownloader.logger.notice("Pause download of image \(download.fileURL.lastPathComponent) with resume data (\(ImageDownloader.activeDownloads.count) active downloads)")
#endif
                    download.resumeData = data
                } else {
#if DEBUG
                    ImageDownloader.logger.notice("Cancel download of image \(download.fileURL.lastPathComponent) without resume data (\(ImageDownloader.activeDownloads.count) active downloads)")
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
        guard let download = ImageDownloader.activeDownloads[imageURL]
        else { return }

        // Cancel the download request
#if DEBUG
        ImageDownloader.logger.notice("Cancel download of image \(download.fileURL.lastPathComponent) (\(ImageDownloader.activeDownloads.count) active downloads)")
#endif
        download.task?.cancel()
        download.task = nil
    }
}
