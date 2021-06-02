//
//  NetworkVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import piwigoKit

class NetworkVars: NSObject {

    // Singleton
    @objc static let shared = NetworkVars()
    
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
    @objc var serverProtocol: String
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var serverPath: String
    
    /// - String encoding of the server, UTF-8 by default
    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc var stringEncoding: UInt
    
    /// -  Username provided to access a server requiring HTTP basic authentication
    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var httpUsername: String

    /// - Username provided to access the Piwigo server
    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var username: String

    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - Session manager used to communicate with the Piwigo server
    @objc var sessionManager: AFHTTPSessionManager?
    
    /// - Session manager used to download images
    @objc var imagesSessionManager: AFHTTPSessionManager?
    
    // - Image and thumbnail caches
    @objc var imageCache: URLCache?
    @objc var thumbnailCache: AFAutoPurgingImageCache?
    
    /// - Community methods available, false by default (available since  version 2.9 of the plugin)
    @objc var usesCommunityPluginV29 = false
    
    /// - uploadAsync method available, false by default (avaiable since Piwigo 11)
    @objc var usesUploadAsync = false
    
    /// - Remembers that the HTTP authentication failed
    @objc var didFailHTTPauthentication = false

    /// - Remembers that the SSL certicate was approved
    @objc var didApproveCertificate = false
    
    /// - Remembers that the SSL certificate was rejected
    @objc var didRejectCertificate = false
    
    /// - Remembers certificate information
    @objc var certificateInformation = ""

    /// - Remembers that the user cancelled login attempt
    @objc var userCancelledCommunication = false
    
    /// - Logged user has normal rigths, false by default
    @objc var hasNormalRights = false

    /// - Logged user has admin rigths, false by default
    @objc var hasAdminRights = false

    /// - Did open session with success
    @objc var hadOpenedSession = false
    
    /// - Remembers when the user logged in
    @objc var dateOfLastLogin: Date = .distantPast
    
    /// - Piwigor server version
    @objc var version = ""
    
    /// - Token returned after login
    @objc var pwgToken = ""

    /// - User's default language
    @objc var language = ""
}
