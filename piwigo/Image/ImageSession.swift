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
    static var shared = ImageSession()
    
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
        
        /// Create the main session and set its description
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.sessionDescription = "Image Session"
        
        return session
    }()
    

    // MARK: - Session Methods
    func setImage(withURL imageURL: URL, cachedAt fileURL: URL, placeHolder: UIImage,
                  success: @escaping (UIImage) -> Void,
                  failure: @escaping (Error?) -> Void) {
        // Get cached image
        if let cachedImage: UIImage = UIImage(contentsOfFile: fileURL.path),
           let cgImage = cachedImage.cgImage, cgImage.height * cgImage.bytesPerRow > 0,
           cachedImage != placeHolder {
            print("••> Image \(fileURL.lastPathComponent) retrieved from cache.")
            success(cachedImage)
            return
        }

        // Retrieve the image file
        downloadImage(atURL: imageURL, cachingAtURL: fileURL) { downloadedImage in
            success(downloadedImage)
        } failure: { error in
            failure(error)
        }
    }

    public func downloadImage(atURL imageURL: URL, cachingAtURL fileURL: URL,
                              fileSize: Int64 = NSURLSessionTransferSizeUnknown,
                              success: @escaping (UIImage) -> Void,
                              failure: @escaping (Error?) -> Void) {
        // Create download task
        let request = URLRequest(url: imageURL)
        let task = dataSession.dataTask(with: request) { data, response, error in
            // Check returned image data
            guard let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                  let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                  let data = data, error == nil, let image = UIImage(data: data) else {
                print("••> Could not download image from \(imageURL.absoluteString): \(error?.localizedDescription ?? "Unknown!")")
                failure(error)
                return
            }
            
            // Store image in cache (in the background)
            DispatchQueue.global(qos: .background).async {
                // Create parent directories if needed
                let fm = FileManager.default
                let dirURL = fileURL.deletingLastPathComponent()
                if fm.fileExists(atPath: dirURL.path) == false {
                    print("••> Create directory \(dirURL.path)")
                    try? fm.createDirectory(at: dirURL, withIntermediateDirectories: true,
                                            attributes: nil)
                }

                // Delete already existing file if it exists (incomplete previous attempt?)
                try? FileManager.default.removeItem(at: fileURL)

                // Store image data
                let success = FileManager.default.createFile(atPath: fileURL.path, contents: data)
                print("••> Image \(fileURL.lastPathComponent) stored in cache: \(success ? "YES" : "NO")")
            }
            
            // Return image object
            success(image)
        }
        
        // Tell the system how many bytes are expected to be exchanged
        task.countOfBytesClientExpectsToSend = Int64((request.allHTTPHeaderFields ?? [:]).count)
        task.countOfBytesClientExpectsToReceive = fileSize
        
        // Launch download in background
        DispatchQueue.global(qos: .userInitiated).async {
            task.resume()
        }
    }
}


// MARK: - Session Delegate
extension ImageSession: URLSessionDelegate {

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        print("    > The data session has been invalidated")
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
extension ImageSession: URLSessionDataDelegate {
    
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
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("    > Data task has received some of the expected data")
        
        // Update UI
//        let uploadInfo: [String : Any] = ["localIdentifier" : identifier,
//                                          "stateLabel" : kPiwigoUploadState.uploading.stateInfo,
//                                          "progressFraction" : progressFraction]
//        DispatchQueue.main.async {
//            // Update UploadQueue cell and button shown in root album (or default album)
//            NotificationCenter.default.post(name: .pwgUploadProgress, object: nil, userInfo: uploadInfo)
//        }
    }
}
