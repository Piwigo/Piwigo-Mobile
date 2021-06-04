//
//  NetworkVarsObjc.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import piwigoKit

class NetworkVarsObjc: NSObject {

    // Singleton
    @objc static let shared = NetworkVarsObjc()
    
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
    /// - Scheme of the URL, "https://" by default
//    @UserDefault("serverProtocol", defaultValue: "http://", userDefaults: UserDefaults.dataSuite)
    @objc var serverProtocol: String {
        get { return NetworkVars.shared.serverProtocol }
        set (value) { NetworkVars.shared.serverProtocol = value }
    }
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
//    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var serverPath: String {
        get { return NetworkVars.shared.serverPath }
        set (value) { NetworkVars.shared.serverPath = value }
    }
    
    /// - String encoding of the server, UTF-8 by default
//    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc var stringEncoding: UInt {
        get { return NetworkVars.shared.stringEncoding }
        set (value) { NetworkVars.shared.stringEncoding = value }
    }
    
    /// -  Username provided to access a server requiring HTTP basic authentication
//    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var httpUsername: String {
        get { return NetworkVars.shared.httpUsername }
        set (value) { NetworkVars.shared.httpUsername = value }
    }

    /// - Username provided to access the Piwigo server
//    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc var username: String {
        get { return NetworkVars.shared.username }
        set (value) { NetworkVars.shared.username = value }
    }

    
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
    @objc var usesCommunityPluginV29: Bool {
        get { return NetworkVars.shared.usesCommunityPluginV29 }
        set (value) { NetworkVars.shared.usesCommunityPluginV29 = value }
    }
    
    /// - uploadAsync method available, false by default (avaiable since Piwigo 11)
    @objc var usesUploadAsync: Bool {
        get { return NetworkVars.shared.usesUploadAsync }
        set (value) { NetworkVars.shared.usesUploadAsync = value }
    }
    
    /// - Remembers that the HTTP authentication failed
    @objc var didFailHTTPauthentication: Bool {
        get { return NetworkVars.shared.didFailHTTPauthentication }
        set (value) { NetworkVars.shared.didFailHTTPauthentication = value }
    }

    /// - Remembers that the SSL certicate was approved
    @objc var didApproveCertificate: Bool {
        get { return NetworkVars.shared.didApproveCertificate }
        set (value) { NetworkVars.shared.didApproveCertificate = value }
    }
    
    /// - Remembers that the SSL certificate was rejected
    @objc var didRejectCertificate: Bool {
        get { return NetworkVars.shared.didRejectCertificate }
        set (value) { NetworkVars.shared.didRejectCertificate = value }
    }
    
    /// - Remembers certificate information
    @objc var certificateInformation: String {
        get { return NetworkVars.shared.certificateInformation }
        set (value) { NetworkVars.shared.certificateInformation = value }
    }

    /// - Remembers that the user cancelled login attempt
    @objc var userCancelledCommunication: Bool {
        get { return NetworkVars.shared.userCancelledCommunication }
        set (value) { NetworkVars.shared.userCancelledCommunication = value }
    }
    
    /// - Logged user has normal rigths, false by default
    @objc var hasNormalRights: Bool {
        get { return NetworkVars.shared.hasNormalRights }
        set (value) { NetworkVars.shared.hasNormalRights = value }
    }

    /// - Logged user has admin rigths, false by default
    @objc var hasAdminRights: Bool {
        get { return NetworkVars.shared.hasAdminRights }
        set (value) { NetworkVars.shared.hasAdminRights = value }
    }

    /// - Did open session with success
    @objc var hadOpenedSession: Bool {
        get { return NetworkVars.shared.hadOpenedSession }
        set (value) { NetworkVars.shared.hadOpenedSession = value }
    }
    
    /// - Remembers when the user logged in
    @objc var dateOfLastLogin: Date {
        get { return NetworkVars.shared.dateOfLastLogin }
        set (value) { NetworkVars.shared.dateOfLastLogin = value }
    }
    
    /// - Piwigor server version
    @objc var version: String {
        get { return NetworkVars.shared.version }
        set (value) { NetworkVars.shared.version = value }
    }
    
    /// - Token returned after login
    @objc var pwgToken: String {
        get { return NetworkVars.shared.pwgToken }
        set (value) { NetworkVars.shared.pwgToken = value }
    }

    /// - User's default language
    @objc var language: String {
        get { return NetworkVars.shared.language }
        set (value) { NetworkVars.shared.language = value }
    }
}
