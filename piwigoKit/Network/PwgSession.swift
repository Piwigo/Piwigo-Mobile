//
//  PwgSession.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 08/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import os
import Foundation
import UniformTypeIdentifiers


public final class PwgSession: NSObject {
    
    // Logs networking activities
    /// sudo log collect --device --start '2023-04-07 15:00:00' --output piwigo.logarchive
    static let logger = Logger(subsystem: "org.piwigo.piwigoKit", category: String(describing: PwgSession.self))
    
    // Singleton
    public static let shared = PwgSession()
    
    // Create single session
    public lazy var dataSession: URLSession = {
        let config = URLSessionConfiguration.default
        
        /// Network service type for data that the user is actively waiting for.
        config.networkServiceType = .responsiveData
        
        /// The foreground session should wait for connectivity to become available.
        config.waitsForConnectivity = true
        
        /// Connections should use the network when the user has specified Low Data Mode
        // config.allowsConstrainedNetworkAccess = true
        
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
        session.sessionDescription = "Main Session"
        
        return session
    }()
    
    // Active downloads
    lazy var activeDownloads: [URL : ImageDownload] = [ : ]
}
