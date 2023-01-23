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
    func startDownload(_ download: ImageDownload) {
        // Create the download request
        let request = URLRequest(url: download.imageURL)

        // Download this image
        download.task = ImageSession.shared.dataSession.downloadTask(with: request)
        download.task?.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        download.task?.countOfBytesClientExpectsToReceive = download.fileSize
        download.task?.resume()
        activeDownloads[download.imageURL] = download
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
        print("••> Did complete task #\(task.taskIdentifier) with error: \(String(describing: error))")
        guard let imageURL = task.originalRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        if let error = error {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(error)
            }
        } else {
            // Return cached image with completionHandler
            if let completion = download.completionHandler,
               let fileURL = download.fileURL {
                if let cachedImage = UIImage(contentsOfFile: fileURL.path) {
                    completion(cachedImage)             // Cached image
                } else {
                    completion(download.placeHolder)    // Cached video
                }
            }
        }
        
        // Remove task from active downloads
        activeDownloads.removeValue(forKey: imageURL)
    }
}


// MARK: Session Download Delegate
extension ImageSession: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        // Retrieve the original URL of this task
        guard let imageURL = downloadTask.originalRequest?.url,
              let download = activeDownloads[imageURL] else {
            return
        }

        // Update progress bar if any
        if let progressHandler = download.progressHandler {
            let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            progressHandler(progress)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Retrieve the original URL of this task
        print("••> Task #\(downloadTask.taskIdentifier) did finish downloading.")
        guard let imageURL = downloadTask.originalRequest?.url,
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
            print("••> Image \(fileURL.lastPathComponent) stored in cache")
        } catch {
            // Return error with failureHandler
            if let failure = download.failureHandler {
                failure(error)
            }
            
            // Remove task from active downloads
            activeDownloads.removeValue(forKey: imageURL)
        }
    }
}
