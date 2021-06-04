//
//  NetworkVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation

public class NetworkVars: NSObject {

    // Singleton
    public static let shared = NetworkVars()
    
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
    @UserDefault("serverProtocol", defaultValue: "http://", userDefaults: UserDefaults.dataSuite)
    public var serverProtocol: String
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var serverPath: String
    
    /// - String encoding of the server, UTF-8 by default
    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    public var stringEncoding: UInt
    
    /// -  Username provided to access a server requiring HTTP basic authentication
    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var httpUsername: String

    /// - Username provided to access the Piwigo server
    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var username: String

    
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
    public var usesCommunityPluginV29 = false
    
    /// - uploadAsync method available, false by default (avaiable since Piwigo 11)
    public var usesUploadAsync = false
    
    /// - Remembers that the HTTP authentication failed
    public var didFailHTTPauthentication = false

    /// - Remembers that the SSL certicate was approved
    public var didApproveCertificate = false
    
    /// - Remembers that the SSL certificate was rejected
    public var didRejectCertificate = false
    
    /// - Remembers certificate information
    public var certificateInformation = ""

    /// - Remembers that the user cancelled login attempt
    public var userCancelledCommunication = false
    
    /// - Logged user has normal rigths, false by default
    public var hasNormalRights = false

    /// - Logged user has admin rigths, false by default
    public var hasAdminRights = false

    /// - Did open session with success
    public var hadOpenedSession = false
    
    /// - Remembers when the user logged in
    public var dateOfLastLogin: Date = .distantPast
    
    /// - Piwigor server version
    public var version = ""
    
    /// - Token returned after login
    public var pwgToken = ""

    /// - User's default language
    public var language = ""
}
