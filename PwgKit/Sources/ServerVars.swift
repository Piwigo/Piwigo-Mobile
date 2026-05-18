//
//  ServerVars.swift
//  PwgKit
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import SystemConfiguration
import RegexBuilder

// Mark ServerVars as Sendable since Apple documents UserDefaults as thread-safe
// and pwgUserStatus is Sendable
public final class ServerVars: @unchecked Sendable {
    
    // Singleton
    public static let shared = ServerVars()
    
    // Constants
    public let minChunkSize: Int = 500                          // i.e. 500 kB
    public let maxChunkSize: Int = 5000                         // i.e. 5_000 kB

    // Functions
    public func domain() -> String {
        let strURL = "\(serverProtocol)\(serverPath)"
        return URL(string: strURL)?.host ?? ""
    }
    
    // Remove deprecated stored objects if needed
    init() {
        // Deprecated data?
//        if let _ = UserDefaults.standard.object(forKey: "test") {
//            UserDefaults.standard.removeObject(forKey: "test")
//        }
        if let _ = UserDefaults.dataSuite.object(forKey: "usesUploadAsync") {
            UserDefaults.dataSuite.removeObject(forKey: "usesUploadAsync")
        }
        if let _ = UserDefaults.dataSuite.object(forKey: "usesCalcOrphans") {
            UserDefaults.dataSuite.removeObject(forKey: "usesCalcOrphans")
        }
    }
    
    // MARK: - Vars in UserDefaults / Standard
    // Server variables stored in UserDefaults / Standard
    /// - Request server update once a month max
    @UserDefault("dateOfLastUpdateRequest", defaultValue: Date().timeIntervalSinceReferenceDate)
    public var dateOfLastUpdateRequest: TimeInterval

    /// - Recent period in number of days
    public let recentPeriodKey = 594 // i.e. key used to detect the behaviour of the slider (sum of all periods)
    public let recentPeriodList:[Int] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,25,30,40,50,60,80,99]
    @UserDefault("recentPeriodIndex", defaultValue: 7)      // i.e index of the period of 7 days
    public var recentPeriodIndex: Int
    
    public let recentPeriodListChangedInVersion312 = "3.1.2"
    @UserDefault("recentPeriodIndexCorrectedInVersion321", defaultValue: false)
    public var recentPeriodIndexCorrectedInVersion321: Bool
    
    public func correctRecentPeriodIndex() {
        // "0 day" option added in v3.1.2 for allowing user to disable "recent" icon
        if recentPeriodIndexCorrectedInVersion321 == false,
           let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           version.compare(recentPeriodListChangedInVersion312) == .orderedSame {
            recentPeriodIndex += 1
            recentPeriodIndexCorrectedInVersion321 = true
        }
    }
    

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
    
    /// - Chunk size suggested by the Piwigo server (500 KB by default)
    @UserDefault("uploadChunkSize", defaultValue: 500, userDefaults: UserDefaults.dataSuite)
    public var uploadChunkSize: Int
    
    /// - Chunk size set by the user (uploadChunkSize by default - see above)
    @UserDefault("customUploadChunkSize", defaultValue: 0, userDefaults: UserDefaults.dataSuite)
    public var customUploadChunkSize: Int
    
    /// - String encoding of the server, UTF-8 by default
    @UserDefault("stringEncoding", defaultValue: String.Encoding.utf8.rawValue, userDefaults: UserDefaults.dataSuite)
    public var stringEncoding: UInt
    
    /// -  Username provided to access a server requiring HTTP basic authentication
    @UserDefault("HttpUsername", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var httpUsername: String
    
    /// - Username provided to access the Piwigo server, i.e. username or API public key
    @UserDefault("username", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var username: String
    
    /// - Username returned by the Piwigo server, introduced in v4.1.2 for correcting user attribution in persistent cache
    @UserDefault("user", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var user: String
    
    /// - Tells whether
    @UserDefault("fixUserIsAPIKeyV412", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var fixUserIsAPIKeyV412: Bool
    public func createPiwigoUsernameAccountIfNeeded() {
        // 'user' added in v4.1.2 for dissociating persistent cache data from credentials
        if ServerVars.shared.user.isEmpty,
           ServerVars.shared.username.isEmpty == false &&
            ServerVars.shared.username.lowercased() != "guest" {
            // Adopts login username, i.e. Piwigo username or API key
            ServerVars.shared.user = ServerVars.shared.username
            // If the user is using an API key:
            /// - 1. Call API method to retrieve the Piwigo user
            /// - 2. Attribute 'API key' upload requests to 'Piwigo user' in persistent cache
            /// - 3. Delete API key 'username', thereby albums associated to it
            /// See PwgSession+Utilities
            if ServerVars.shared.username.isValidPublicKey() {
                ServerVars.shared.fixUserIsAPIKeyV412 = true
            }
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
    
    /// - IDs of albums in which a Community user can create sub-albums (Int32.min if unknown, i.e. Piwigo version before 16.4)
//    @UserDefault("createAlbumRights", defaultValue: "\(Int32.min)", userDefaults: UserDefaults.dataSuite)
//    public var createAlbumRights: String
    
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
    
    /// - pwg.images.setCategory method available, false by default (available since Piwigo 14)
    @UserDefault("usesSetCategory", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesSetCategory: Bool
    
    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - Remembers whether the device is connected to Wi-FI
    public var isConnectedToWiFi: Bool = false
    
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
        
    /// - Available image sizes
    public var hasSquareSizeImages = false
    public var hasThumbSizeImages = false
    public var hasXXSmallSizeImages = false
    public var hasXSmallSizeImages = false
    public var hasSmallSizeImages = false
    public var hasMediumSizeImages = false
    public var hasLargeSizeImages = false
    public var hasXLargeSizeImages = false
    public var hasXXLargeSizeImages = false
    public var hasXXXLargeSizeImages = false
    public var hasXXXXLargeSizeImages = false

    /// — Will tell if the network connection has changed
    public var hasNetworkConnectionChanged = false
    
    /// — True if the app should log visits and downloads (since Piwigo 14)
    public var saveVisits = false
    
    /// - To force the app to login at launch
    public var applicationShouldRelogin: Bool = true
}

extension pwgImageSize {
    // Availability on server
    public var isAvailable: Bool {
        switch self {
        case .square:
            return ServerVars.shared.hasSquareSizeImages
        case .thumb:
            return ServerVars.shared.hasThumbSizeImages
        case .xxSmall:
            return ServerVars.shared.hasXXSmallSizeImages
        case .xSmall:
            return ServerVars.shared.hasXSmallSizeImages
        case .small:
            return ServerVars.shared.hasSmallSizeImages
        case .medium:
            return ServerVars.shared.hasMediumSizeImages
        case .large:
            return ServerVars.shared.hasLargeSizeImages
        case .xLarge:
            return ServerVars.shared.hasXLargeSizeImages
        case .xxLarge:
            return ServerVars.shared.hasXXLargeSizeImages
        case .xxxLarge:
            return ServerVars.shared.hasXXXLargeSizeImages
        case .xxxxLarge:
            return ServerVars.shared.hasXXXXLargeSizeImages
        case .fullRes:
            return true
        }
    }
}


// MARK: - API Key Management
extension String
{
    public
    func isValidPublicKey() -> Bool {
        if #available(iOS 16.0, *) {
            let pattern = Regex {
                "pkid-"
                Repeat(.digit, count: 8)
                "-"
                Repeat(.anyOf("abcdefghijklmnopqrstuvwxyz0123456789"), count: 20)
            }
            return self.wholeMatch(of: pattern.ignoresCase()) != nil
        } else {
            // Fallback on previous version
            let pattern = "^pkid-\\d{8}-[a-z0-9]{20}$"
            return self.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
