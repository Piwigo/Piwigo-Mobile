//
//  NetworkVars.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import SystemConfiguration

public class NetworkVars: NSObject {

    public static func domain() -> String {
        let strURL = "\(serverProtocol)\(serverPath)"
        return URL(string: strURL)?.host ?? ""
    }

    public static func isConnectedToWiFi() -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault,
                                                                     domain()) else { return false }
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }
        
        let isReachable = flags.contains(.reachable)
        let cellular = flags.contains(.isWWAN)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !cellular && !needsConnection)
    }

    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Network variables stored in UserDefaults / Standard
    /// - None

    
    // MARK: - Vars in UserDefaults / App Group
    // Network variables stored in UserDefaults / App Group
    /// - Scheme of the URL, "https://" by default
    @UserDefault("serverProtocol", defaultValue: "https://", userDefaults: UserDefaults.dataSuite)
    public static var serverProtocol: String
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var serverPath: String
    
    /// - String encoding of the server, UTF-8 by default
    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    public static var stringEncoding: UInt
    
    /// -  Username provided to access a server requiring HTTP basic authentication
    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var httpUsername: String

    /// - Username provided to access the Piwigo server
    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public static var username: String

    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - Session manager used to communicate with the Piwigo server
//    var sessionManager: AFHTTPSessionManager?
    
    /// - Session manager used to download images
//    var imagesSessionManager: AFHTTPSessionManager?
    
    // - Image and thumbnail caches
//    var imageCache: URLCache?
//    var thumbnailCache: AFAutoPurgingImageCache?
    
    /// - Community methods available, false by default (available since  version 2.9 of the plugin)
    public static var usesCommunityPluginV29 = false
    
    /// - uploadAsync method available, false by default (avaiable since Piwigo 11)
    public static var usesUploadAsync = false
    
    /// - Remembers that the HTTP authentication failed
    public static var didFailHTTPauthentication = false

    /// - Remembers that the SSL certicate was approved
    public static var didApproveCertificate = false
    
    /// - Remembers that the SSL certificate was rejected
    public static var didRejectCertificate = false
    
    /// - Remembers certificate information
    public static var certificateInformation = ""

    /// - Remembers that the user cancelled login attempt
    public static var userCancelledCommunication = false
    
    /// - Logged user has guest rigths, false by default
    public static var hasGuestRights = false

    /// - Logged user has normal rigths, false by default
    public static var hasNormalRights = false

    /// - Logged user has admin rigths, false by default
    public static var hasAdminRights = false

    /// - Remembers when the user logged in
    public static var dateOfLastLogin: Date = .distantPast
    
    /// - Piwigor server version
    public static var pwgVersion = ""
    
    /// - Token returned after login
    public static var pwgToken = ""

    /// - User's default language
    public static var language = ""
}
