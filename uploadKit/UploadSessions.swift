//
//  UploadSessions.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 22/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import Foundation
import piwigoKit

// Background tasks
public let pwgBackgroundUploadTask = "\(Bundle.main.bundleIdentifier!).uploadManager"
public let pwgBackgroundContinuedUploadTask = "\(Bundle.main.bundleIdentifier!).uploadManagerContinued"

@MainActor
public var uploadSessionCompletionHandler: (() -> Void)?

// Custom HTTP headers
public let pwgHTTPuploadID  = "X-PWG-UploadID"              // Added to HTTP header
public let pwgHTTPimageID   = "X-PWG-localIdentifier"       // Added to HTTP header
public let pwgHTTPchunk     = "X-PWG-chunk"                 // Added to HTTP header
public let pwgHTTPchunks    = "X-PWG-chunks"                // Added to HTTP header
public let pwgHTTPmd5sum    = "X-PWG-md5sum"                // Added to HTTP header
public let pwgHTTPCancelled = "PWG Task Cancelled"          // Appended to task description

// URLSession delegate
public let pwgUploadDelegate = UploadSessionsDelegate.shared.self


// MARK: - Foreground Upload Session
public let uploadSessionIdentifier:String! = "org.piwigo.uploadSession"
public let frgdSession: URLSession = {
    let config = URLSessionConfiguration.default
    
    /// The foreground session should wait for connectivity to become available (can be retried)
    /// only when the app uses the pwg.images.uploadAsync method.
//        config.waitsForConnectivity = NetworkVars.shared.usesUploadAsync
    
    /// Connections should not use the network when the user has specified Low Data Mode
//        config.allowsConstrainedNetworkAccess = false

    /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
    config.allowsCellularAccess = !(UploadVars.shared.wifiOnlyUploading)
    
    /// How long a task should wait for additional data to arrive before giving up (1 minute)
    config.timeoutIntervalForRequest = 60
    
    /// How long an upload task should be allowed to be retried or transferred (5 minutes).
    config.timeoutIntervalForResource = 300
    
    /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
    config.httpMaximumConnectionsPerHost = 4
    
    /// Do not return a response from the cache
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    
    /// Do not send upload requests with cookie so that each upload session remains ephemeral.
    /// The user session, if it exists, remains untouched and kept alive until it expires.
    config.httpShouldSetCookies = true
    config.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
    
    /// Allows a seamless handover from Wi-Fi to cellular
    config.multipathServiceType = .handover
    
    /// Create the background session and set its description
    let session = URLSession(configuration: config, delegate: pwgUploadDelegate, delegateQueue: nil)
    session.sessionDescription = "Upload Session (frgd)"
    
    return session
}()


// MARK: - Background Upload Session
public let uploadBckgSessionIdentifier:String! = "org.piwigo.uploadBckgSession"
public let bckgSession: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: uploadBckgSessionIdentifier)
    
    /// Background tasks can be scheduled at the discretion of the system for optimal performance
    config.isDiscretionary = false

    /// Indicates whether the app should be resumed or launched in the background when transfers finish
    config.sessionSendsLaunchEvents = true
    
    /// Indicates whether TCP connections should be kept open when the app moves to the background
    config.shouldUseExtendedBackgroundIdleMode = true

    /// Indicates whether the request is allowed to use the built-in cellular radios to satisfy the request.
    config.allowsCellularAccess = !(UploadVars.shared.wifiOnlyUploading)
    
    /// How long a task should wait for additional data to arrive before giving up (1 day)
    config.timeoutIntervalForRequest = 1 * 24 * 60 * 60
    
    /// How long an upload task should be allowed to be retried or transferred (7 days).
    config.timeoutIntervalForResource = 7 * 24 * 60 * 60
    
    /// Determines the maximum number of simultaneous connections made to the host by tasks (4 by default)
    config.httpMaximumConnectionsPerHost = 4
    
    /// Do not return a response from the cache
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    
    /// The user session, if it exists, should remain untouched so  we do not update the Piwigo cookie.
    /// We send a custom cookie to avoid a reject by ModSecurity if it is set to reject requests not containing cookies.
    config.httpShouldSetCookies = false
    config.httpCookieAcceptPolicy = .never
    if let validUrl = URL(string: NetworkVars.shared.service) {
        var params: [HTTPCookiePropertyKey : Any] = [
            HTTPCookiePropertyKey.version           : NSString("0"),
            HTTPCookiePropertyKey.name              : NSString("pwg_method"),
            HTTPCookiePropertyKey.value             : NSString("uploadAsync"),
            HTTPCookiePropertyKey.domain            : NSString(string: validUrl.host ?? ""),
            HTTPCookiePropertyKey.path              : NSString(string: validUrl.path),
            HTTPCookiePropertyKey.expires           : NSDate(),
            HTTPCookiePropertyKey.discard           : NSString("TRUE")
        ]
        if NetworkVars.shared.serverProtocol == "https" {
            params[HTTPCookiePropertyKey.secure] = "TRUE"
        }
        if let cookie = HTTPCookie(properties: params) {
            config.httpAdditionalHeaders = HTTPCookie.requestHeaderFields(with: [cookie])
        }
    }

    /// Allows a seamless handover from Wi-Fi to cellular
    config.multipathServiceType = .handover
    
    /// The identifier for the shared container into which files in background URL sessions should be downloaded.
    config.sharedContainerIdentifier = UserDefaults.appGroup
    
    /// Create the background session and set its description
    let session = URLSession(configuration: config, delegate: pwgUploadDelegate, delegateQueue: nil)
    session.sessionDescription = "Upload Session (bckg)"
    
    return session
}()
