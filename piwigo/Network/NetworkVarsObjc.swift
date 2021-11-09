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
//    @UserDefault("serverProtocol", defaultValue: "https://", userDefaults: UserDefaults.dataSuite)
    @objc static var serverProtocol: String {
        get { return NetworkVars.serverProtocol }
        set (value) { NetworkVars.serverProtocol = value }
    }
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
//    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var serverPath: String {
        get { return NetworkVars.serverPath }
        set (value) { NetworkVars.serverPath = value }
    }
    
    /// - String encoding of the server, UTF-8 by default
//    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    @objc static var stringEncoding: UInt {
        get { return NetworkVars.stringEncoding }
        set (value) { NetworkVars.stringEncoding = value }
    }
    
    /// -  Username provided to access a server requiring HTTP basic authentication
//    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var httpUsername: String {
        get { return NetworkVars.httpUsername }
        set (value) { NetworkVars.httpUsername = value }
    }

    /// - Username provided to access the Piwigo server
//    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    @objc static var username: String {
        get { return NetworkVars.username }
        set (value) { NetworkVars.username = value }
    }

    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - Session manager used to communicate with the Piwigo server
    @objc static var sessionManager: AFHTTPSessionManager?
    
    /// - Session manager used to download favorites data in the background
    @objc static var favoritesManager: AFHTTPSessionManager?

    /// - Session manager used to download images
    @objc static var imagesSessionManager: AFHTTPSessionManager?
    
    // - Image and thumbnail caches
    @objc static var imageCache: URLCache?
    @objc static var thumbnailCache: AFAutoPurgingImageCache?

    /// - Community methods available, false by default (available since  version 2.9 of the plugin)
    @objc static var usesCommunityPluginV29: Bool {
        get { return NetworkVars.usesCommunityPluginV29 }
        set (value) { NetworkVars.usesCommunityPluginV29 = value }
    }
    
    /// - uploadAsync method available, false by default (avaiable since Piwigo 11)
    @objc static var usesUploadAsync: Bool {
        get { return NetworkVars.usesUploadAsync }
        set (value) { NetworkVars.usesUploadAsync = value }
    }
    
    /// - Remembers that the HTTP authentication failed
    @objc static var didFailHTTPauthentication: Bool {
        get { return NetworkVars.didFailHTTPauthentication }
        set (value) { NetworkVars.didFailHTTPauthentication = value }
    }

    /// - Remembers that the SSL certicate was approved
    @objc static var didApproveCertificate: Bool {
        get { return NetworkVars.didApproveCertificate }
        set (value) { NetworkVars.didApproveCertificate = value }
    }
    
    /// - Remembers that the SSL certificate was rejected
    @objc static var didRejectCertificate: Bool {
        get { return NetworkVars.didRejectCertificate }
        set (value) { NetworkVars.didRejectCertificate = value }
    }
    
    /// - Remembers certificate information
    @objc static var certificateInformation: String {
        get { return NetworkVars.certificateInformation }
        set (value) { NetworkVars.certificateInformation = value }
    }

    /// - Remembers that the user cancelled login attempt
    @objc static var userCancelledCommunication: Bool {
        get { return NetworkVars.userCancelledCommunication }
        set (value) { NetworkVars.userCancelledCommunication = value }
    }
    
    /// - Logged user has guest rigths, false by default
    @objc static var hasGuestRights: Bool {
        get { return NetworkVars.hasGuestRights }
        set (value) { NetworkVars.hasGuestRights = value }
    }

    /// - Logged user has normal rigths, false by default
    @objc static var hasNormalRights: Bool {
        get { return NetworkVars.hasNormalRights }
        set (value) { NetworkVars.hasNormalRights = value }
    }

    /// - Logged user has admin rigths, false by default
    @objc static var hasAdminRights: Bool {
        get { return NetworkVars.hasAdminRights }
        set (value) { NetworkVars.hasAdminRights = value }
    }

    /// - Did open session with success
    @objc static var hadOpenedSession: Bool {
        get { return NetworkVars.hadOpenedSession }
        set (value) { NetworkVars.hadOpenedSession = value }
    }
    
    /// - Remembers when the user logged in
    @objc static var dateOfLastLogin: Date {
        get { return NetworkVars.dateOfLastLogin }
        set (value) { NetworkVars.dateOfLastLogin = value }
    }
    
    /// - Piwigor server version
    @objc static var pwgVersion: String {
        get { return NetworkVars.pwgVersion }
        set (value) { NetworkVars.pwgVersion = value }
    }
    
    /// - Token returned after login
    @objc static var pwgToken: String {
        get { return NetworkVars.pwgToken }
        set (value) { NetworkVars.pwgToken = value }
    }

    /// - User's default language
    @objc static var language: String {
        get { return NetworkVars.language }
        set (value) { NetworkVars.language = value }
    }
}
