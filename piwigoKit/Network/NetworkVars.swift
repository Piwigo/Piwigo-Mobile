//
//  NetworkVars.shared.swift
//  piwigoKit
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import SystemConfiguration

// Mark NetworkVars as Sendable since Apple documents UserDefaults as thread-safe
// and pwgUserStatus is Sendable
public class NetworkVars: NSObject, @unchecked Sendable {
    
    // Singleton
    public static let shared = NetworkVars()
    
    public func domain() -> String {
        let strURL = "\(serverProtocol)\(serverPath)"
        return URL(string: strURL)?.host ?? ""
    }
        
    // Remove deprecated stored objects if needed
    //    override init() {
    //        // Deprecated data?
    //        if let _ = UserDefaults.standard.object(forKey: "test") {
    //            UserDefaults.standard.removeObject(forKey: "test")
    //        }
    //        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
    //            UserDefaults.dataSuite.removeObject(forKey: "test")
    //        }
    //    }
    
    // MARK: - Vars in UserDefaults / Standard
    // Network variables stored in UserDefaults / Standard
    /// - Request server update once a month max
    @UserDefault("dateOfLastUpdateRequest", defaultValue: Date().timeIntervalSinceReferenceDate)
    public var dateOfLastUpdateRequest: TimeInterval

    
    // MARK: - Vars in UserDefaults / App Group
    // Network variables stored in UserDefaults / App Group
    /// - Scheme of the URL, "https://" by default
    @UserDefault("serverProtocol", defaultValue: "https://", userDefaults: UserDefaults.dataSuite)
    public var serverProtocol: String {
        didSet {
            service = serverProtocol + serverPath
        }
    }
    
    /// - Path of the server, e.g. lelievre-berna.net/Piwigo
    @UserDefault("serverPath", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var serverPath: String {
        didSet {
            service = serverProtocol + serverPath
        }
    }
    
    /// - String encoding of the server, UTF-8 by default
    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    public var stringEncoding: UInt
    
    /// -  Username provided to access a server requiring HTTP basic authentication
    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var httpUsername: String
    
    /// - Username provided to access the Piwigo server, i.e. username or API public key
    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var username: String
    
    /// - Username returned by the Piwigo server
    @UserDefault("user", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var user: String
    
    public func initPiwigoUsernameAccount() {
        // Piwigo account added in v4.1.2 for dissociating persistent cache data from credentials
        if NetworkVars.shared.user.isEmpty,
           NetworkVars.shared.username.isEmpty == false &&
            NetworkVars.shared.username.lowercased() != "guest" {
            NetworkVars.shared.user = NetworkVars.shared.username
        }
    }
    
    /// - Status of the user accessing the Piwigo server
    @UserDefault("userStatusRaw", defaultValue: pwgUserStatus.guest.rawValue, userDefaults: UserDefaults.dataSuite)
    private var userStatusRaw: String
    public var userStatus: pwgUserStatus {
        get { return pwgUserStatus(rawValue: userStatusRaw) ?? pwgUserStatus.guest }
        set (value) {
            if pwgUserStatus.allCases.contains(value) {
                userStatusRaw = value.rawValue
            }
        }
    }
    
    /// - Library/Caches/Piwigo/Thumbnail folder size
    @UserDefault("thumbFolderSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public var thumbFolderSize: UInt
    
    /// - Piwigo server version (stored so that the app knows it after a crash and before re-login)
    @UserDefault("pwgVersion", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var pwgVersion: String
    
    /// - Piwigo server statistics (stored so that the app can show them anytime, once loaded)
    @UserDefault("pwgStatistics", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var pwgStatistics: String
    
    /// - File types accepted by the Piwigo server
    @UserDefault("serverFileTypes", defaultValue: "jpg,jpeg,png,gif", userDefaults: UserDefaults.dataSuite)
    public var serverFileTypes: String

    /// - Community methods available, false by default (available since version 2.9 of the plugin)
    @UserDefault("usesCommunityPluginV29", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesCommunityPluginV29:Bool
    
    /// - pwg.images.uploadAsync method available, false by default (avaiable since Piwigo 11)
    @UserDefault("usesUploadAsync", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesUploadAsync: Bool
    
    /// - pwg.categories.calculateOrphans method available, false by default (available since Piwigo 12)
    @UserDefault("usesCalcOrphans", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesCalcOrphans: Bool

    /// - pwg.images.setCategory method available, false by default (available since Piwigo 14)
    @UserDefault("usesSetCategory", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesSetCategory: Bool

    /// - pwg.users.api_key.revoke method available, false by default (available since Piwigo 16)
    @UserDefault("usesAPIkeys", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesAPIkeys: Bool
    
    /// - API methods which are prohibited when making requests with an API key
    @UserDefault("apiKeysProhibitedMethods", defaultValue: Set([pwgSessionLogin, pwgSessionLogout]), userDefaults: UserDefaults.dataSuite)
    public var apiKeysProhibitedMethods: Set<String>
    
    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - Remembers whether the device is connected to Wi-FI
    public var isConnectedToWiFi: Bool = false

    /// - Disconnects and asks to update Piwigo server if version is lower than:
    public let pwgMinVersion = "2.10.0"

    /// - At login, invites to update the Piwigo server if version is lower than:
    public let pwgRecentVersion = "14.0"

    /// - Quicker than calling UserDefaults variables
    public lazy var service = serverProtocol + serverPath
    
    /// - Remembers that the HTTP authentication failed
    public var didFailHTTPauthentication = false
    
    /// - Remembers that the SSL certicate was approved
    public var didApproveCertificate = false
    
    /// - Remembers that the SSL certificate was rejected
    public var didRejectCertificate = false
    
    /// - Remembers certificate information
    public var certificateInformation = ""

    /// - Token returned after login
    public var pwgToken = ""
    
    /// - User's default language
    public var language = ""
    
    /// - Custom HTTP header field names
    public let HTTPCatID = "X-PWG-categoryID"
    
    /// - Available image sizes
    public var hasSquareSizeImages = true
    public var hasThumbSizeImages = true
    public var hasXXSmallSizeImages = false
    public var hasXSmallSizeImages = false
    public var hasSmallSizeImages = false
    public var hasMediumSizeImages = true
    public var hasLargeSizeImages = false
    public var hasXLargeSizeImages = false
    public var hasXXLargeSizeImages = false
    
    /// — True if the app should log visits and downloads (since Piwigo 14)
    public var saveVisits = false
    
    /// - To force the app to login at launch
    public var applicationShouldRelogin: Bool = true
}
