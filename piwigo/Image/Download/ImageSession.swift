//
//  ImageSession.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 22/09/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit
import UniformTypeIdentifiers

class ImageSession: NSObject {
    
    // Singleton
    static let shared = ImageSession()
    
    // Create single instance
    lazy var dataSession: URLSession = {
        let config = URLSessionConfiguration.default
        
        // Will accept the image formats supported by UIImage
        var acceptedTypes = ""
        if #available(iOS 14.0, *) {
            let imageTypes = [UTType.heic, UTType.heif, UTType.ico, UTType.icns, UTType.png, UTType.gif, UTType.jpeg, UTType.webP, UTType.tiff, UTType.bmp, UTType.svg, UTType.rawImage].compactMap {$0.tags[.mimeType]}.flatMap({$0})
            acceptedTypes = String(imageTypes.map { $0 + " ,"}.reduce("", +))
        } else {
            // Fallback on earlier versions
            acceptedTypes = "image/heic, image/heif, image/vnd.microsoft.icon, image/png, image/gif, image/jpeg, image/jpg, image/webp, image/tiff, image/bmp, image/svg+xml, "
        }
        
        // Add text types for handling Piwigo errors and redirects
        acceptedTypes += "text/plain, text/html"
        
        // Additional headers that are added to all tasks
        config.httpAdditionalHeaders = ["Accept"         : acceptedTypes,
                                        "Accept-Charset" : "utf-8"]
        
        /// Network service type for data that the user is actively waiting for.
        config.networkServiceType = .responsiveData
        
        /// Indicates that the request is allowed to use the built-in cellular radios to satisfy the request.
        config.allowsCellularAccess = true

        /// How long a task should wait for additional data to arrive before giving up (30 seconds)
        config.timeoutIntervalForRequest = 30
        
        /// How long a task should be allowed to be retried or transferred (1 minute).
        config.timeoutIntervalForResource = 60
        
        /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
        config.httpMaximumConnectionsPerHost = 4
        
        /// Requests should contain cookies from the cookie store.
        config.httpShouldSetCookies = true
        
        /// Accept all cookies.
        config.httpCookieAcceptPolicy = .always
        
        /// Allows a seamless handover from Wi-Fi to cellular
        config.multipathServiceType = .handover
        
        // Do not store images in URLCache
        config.urlCache = nil
        
        /// Create the main session and set its description
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.sessionDescription = "Image Download Session"
        
        return session
    }()
    
    // Active downloads
    lazy var activeDownloads: [URL : ImageDownload] = [ : ]
    
    
    // MARK: - Asynchronous Methods
    func getImage(withID imageID: Int64, ofSize imageSize: pwgImageSize, atURL imageURL: URL,
                  fromServer serverID: String, fileSize: Int64 = NSURLSessionTransferSizeUnknown,
                  placeHolder: UIImage, progress: ((Float) -> Void)? = nil,
                  completion: @escaping (URL) -> Void, failure: ((Error) -> Void)? = nil) {
        // Create the download request
        let request = URLRequest(url: imageURL)
        
        // Create Download instance
        let download = ImageDownload(imageID: imageID, ofSize: imageSize, atURL: imageURL,
                                     fromServer: serverID, placeHolder: placeHolder,
                                     progress: progress, completion: completion, failure: failure)

        // Do we already have this image in cache?
        if let cachedImage: UIImage = UIImage(contentsOfFile: download.fileURL.path),
           let cgImage = cachedImage.cgImage, cgImage.height * cgImage.bytesPerRow > 0,
           cachedImage != download.placeHolder {
            print("••> Image \(download.fileURL.lastPathComponent) retrieved from cache.")
            completion(download.fileURL)
            return
        }

        // Download this image
        guard let download = activeDownloads[imageURL] else {
            print("••> Launch download: \(imageURL.lastPathComponent)")
            download.task = ImageSession.shared.dataSession.downloadTask(with: request)
            download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
            download.task?.countOfBytesClientExpectsToReceive = download.fileSize
            download.task?.resume()
            activeDownloads[imageURL] = download
            return
        }

        // Resume download
        print("••> Resume download: \(imageURL.lastPathComponent)")
        download.progressHandler = progress
        if let progressHandler = download.progressHandler {
            progressHandler(download.progress)
        }
        download.completionHandler = completion
        download.failureHandler = failure
        if let resumeData = download.resumeData {
            download.task = ImageSession.shared.dataSession.downloadTask(withResumeData: resumeData)
        } else {
            download.task = ImageSession.shared.dataSession.downloadTask(with: request)
        }
        download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        download.task?.countOfBytesClientExpectsToReceive = download.fileSize
        download.task?.resume()
        activeDownloads[imageURL] = download
    }
    
    func pauseDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = activeDownloads[imageURL] else {
            return
        }
        
        // Cancel the download request
        download.task?.cancel(byProducingResumeData: { imageData in
            print("••> Pause download: \(imageURL.lastPathComponent)")
            download.resumeData = imageData
        })
    }
        
    func cancelDownload(atURL imageURL: URL) {
        // Retrieve download instance
        guard let download = activeDownloads[imageURL] else {
            return
        }
        
        // Cancel the download request
        print("••> Cancel download: \(imageURL.lastPathComponent)")
        download.task?.cancel()
        activeDownloads[imageURL] = nil
    }
}


// MARK: - Session Delegate
extension ImageSession: URLSessionDelegate {

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("    > The data session has been invalidated")
        activeDownloads = [ : ]
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Session-level authentication request from the remote server.")
        
        // Get protection space for current domain
        let protectionSpace = challenge.protectionSpace
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              protectionSpace.host.contains(NetworkVars.domain()) else {
                completionHandler(.rejectProtectionSpace, nil)
                return
        }

        // Get state of the server SSL transaction state
        guard let serverTrust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check validity of certificate
        if KeychainUtilities.isSSLtransactionValid(inState: serverTrust,
                                                   for: NetworkVars.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // If there is no certificate, reject server (should rarely happen)
        if SecTrustGetCertificateCount(serverTrust) == 0 {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Retrieve the certificate of the server
        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, CFIndex(0)) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Check if the certificate is trusted by user (i.e. is in the Keychain)
        // Case where the certificate is e.g. self-signed
        if KeychainUtilities.isCertKnownForSSLtransaction(certificate, for: NetworkVars.domain()) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        
        // Could not validate the certificate
        completionHandler(.performDefaultHandling, nil)
    }
}


// MARK: - Session Task Delegate
extension ImageSession: URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("    > Task-level authentication request from the remote server")
        
        // Check authentication method
        let authMethod = challenge.protectionSpace.authenticationMethod
        guard authMethod == NSURLAuthenticationMethodHTTPBasic,
              authMethod == NSURLAuthenticationMethodHTTPDigest else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Get HTTP basic authentification credentials
        let service = NetworkVars.serverProtocol + NetworkVars.serverPath
        let account = NetworkVars.httpUsername
        let password = KeychainUtilities.password(forService: service, account: account)
        if password.isEmpty {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let credential = URLCredential(user: account,
                                       password: password,
                                       persistence: .forSession)
        completionHandler(.useCredential, credential)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Retrieve the original URL of this task
        guard let imageURL = task.currentRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        if let error = error {
            // Return error with failureHandler
            print("••> Did complete task #\(task.taskIdentifier) with error: \(String(describing: error))")
            if let failure = download.failureHandler {
                failure(error)
            }
            if (error as NSError).code != NSURLErrorCancelled {
                // Remove task from active downloads
                activeDownloads.removeValue(forKey: imageURL)
            }
        } else {
            // Return cached image with completionHandler
            print("••> Did complete task #\(task.taskIdentifier)")
            if let completion = download.completionHandler,
               let fileURL = download.fileURL {
                completion(fileURL)
            }
            // Remove task from active downloads
            activeDownloads.removeValue(forKey: imageURL)
        }
    }
}


// MARK: Session Download Delegate
extension ImageSession: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        // Retrieve the original URL of this task
        print("••> Progress task #\(downloadTask.taskIdentifier) -> \(String(describing: downloadTask.currentRequest?.url))")
        var downloads = ""
        activeDownloads.forEach { (key, value) in
            downloads.append(contentsOf: key.lastPathComponent + ", ")
        }
        print("    activeDownloads: \(downloads.dropLast(2))")
        guard let imageURL = downloadTask.currentRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        // Update progress bar if any
        if let progressHandler = download.progressHandler {
            download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            print("••> Progress task #\(downloadTask.taskIdentifier) -> \(download.progress)")
            progressHandler(download.progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Retrieve the URL of this task
        print("••> Task #\(downloadTask.taskIdentifier) did finish downloading.")
        guard let imageURL = downloadTask.currentRequest?.url,
              let download = activeDownloads[imageURL],
              let fileURL = download.fileURL else {
            return
        }

        // Create parent directories if needed
        do {
            let fm = FileManager.default
            let dirURL = fileURL.deletingLastPathComponent()
            if fm.fileExists(atPath: dirURL.path) == false {
                print("••> Create directory \(dirURL.path)")
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true,
                                       attributes: nil)
            }
            
            // Delete already existing file if it exists (incomplete previous attempt?)
            try? fm.removeItem(at: fileURL)
            
            // Store image
            try fm.copyItem(at: location, to: fileURL)
//            print("••> Image \(fileURL.lastPathComponent) stored in cache")
        } catch {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(error)
            }
        }
    }
}
