//
//  AppVars.shared.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import UIKit
import piwigoKit

// Constants
/// - Preferred popover view width on iPad
let pwgPadSubViewWidth = CGFloat(375.0)
///- Preferred Settings view width on iPad
let pwgPadSettingsWidth = CGFloat(512.0)


class AppVars: NSObject {
    
    // Singleton
    static let shared = AppVars()

    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
        if let _ = UserDefaults.standard.object(forKey: "memoryCache") {
            UserDefaults.standard.removeObject(forKey: "memoryCache")
        }
        if let _ = UserDefaults.standard.object(forKey: "diskCache") {
            UserDefaults.standard.removeObject(forKey: "diskCache")
        }
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
    }

    // MARK: - Vars in UserDefaults / Standard
    // Application variables stored in UserDefaults / Standard
    /// - App color palette (adopts light/dark modes as from iOS 13)
    @UserDefault("isDarkPaletteActive", defaultValue: false)
    var isDarkPaletteActive: Bool
    @UserDefault("switchPaletteAutomatically", defaultValue: true)
    var switchPaletteAutomatically: Bool
    @UserDefault("switchPaletteThreshold", defaultValue: 40)
    var switchPaletteThreshold: Int
    @UserDefault("isDarkPaletteModeActive", defaultValue: false)
    var isDarkPaletteModeActive: Bool
    @UserDefault("isLightPaletteModeActive", defaultValue: false)
    var isLightPaletteModeActive: Bool
    
    /// - App Lock option
    @UserDefault("isAppLockActive", defaultValue: false)
    var isAppLockActive: Bool
    @UserDefault("appLockKey", defaultValue: "")
    var appLockKey: String
    @UserDefault("isBiometricsEnabled", defaultValue: true)
    var isBiometricsEnabled: Bool
    
    /// — Clear clipboard after delay option (never by default)
    @UserDefault("clearClipboardDelay", defaultValue: pwgClearClipboard.never.rawValue)
    var clearClipboardDelay: Int

    /// - Remember which help views were watched
    @UserDefault("didWatchHelpViews", defaultValue: 0b00000000_00000000)
    var didWatchHelpViews: UInt16
    
    /// - Remember when the last help view was presented
    @UserDefault("dateOfLastHelpView", defaultValue: Date.distantPast.timeIntervalSinceReferenceDate)
    var dateOfLastHelpView: TimeInterval
    
    /// - Request help for translating Piwigo once a month max
    let pwgOneMonth: TimeInterval = 31.0 * 24.0 * 60.0 * 60.0     // i.e. 31 days
    @UserDefault("dateOfLastTranslationRequest", defaultValue: Date().timeIntervalSinceReferenceDate)
    var dateOfLastTranslationRequest: TimeInterval
    
    /// - Remember for which version the What's New in Piwigo view was presented
    @UserDefault("didShowWhatsNewAppVersion", defaultValue: "2.12.7")
    var didShowWhatsNewAppVersion: String
    
    /// - Remember when the first '-opt' cached image was produced with version 3.2.3
    @UserDefault("dateOfFirstOptImageV323", defaultValue: Date.distantFuture.timeIntervalSinceReferenceDate)
    var dateOfFirstOptImageV323: TimeInterval

    
    // MARK: - Vars in UserDefaults / App Group
    // Application variables stored in UserDefaults / App Group
    /// - None

    
    // MARK: - Vars in Memory
    // Application variables kept in memory
    /// - Is system dark palette active?
    var isSystemDarkModeActive = false
    
    /// - Check for haptics compatibility at the app’s launch
    var supportsHaptics: Bool = false

    /// - App Lock status
    var isAppUnlocked: Bool = false
    
    /// - Number of albums in cache (excepted smart albums) calculated before connecting other scenes
    var nberOfAlbumsInCache: Int = 0
    
    /// - Flag indicating if an external display is connected
    var inSingleDisplayMode: Bool = true
    
    /// - Remember the latest recursive album data fetch
    var dateOfLatestRecursiveAlbumDataFetch = Date.distantPast
    
    /// - To prevent background tasks from running when the app is active
    var applicationIsActive: Bool = false
    
    /// - Remember that a database migration is running to prevent a crash when the app is going to background.
    var isMigrationRunning: Bool = false
}
