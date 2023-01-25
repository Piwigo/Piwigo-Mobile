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
    @objc static let shared = AppVars()

    // Remove deprecated stored objects if needed
//    override init() {
//        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
//    }

    // MARK: - Vars in UserDefaults / Standard
    // Application variables stored in UserDefaults / Standard
    /// - App color palette (adopts light/dark modes as from iOS 13)
    @UserDefault("isDarkPaletteActive", defaultValue: false)
    @objc var isDarkPaletteActive: Bool
    @UserDefault("switchPaletteAutomatically", defaultValue: true)
    @objc var switchPaletteAutomatically: Bool
    @UserDefault("switchPaletteThreshold", defaultValue: 40)
    @objc var switchPaletteThreshold: Int
    @UserDefault("isDarkPaletteModeActive", defaultValue: false)
    @objc var isDarkPaletteModeActive: Bool
    @UserDefault("isLightPaletteModeActive", defaultValue: false)
    @objc var isLightPaletteModeActive: Bool
    
    /// - App Lock option
    @UserDefault("isAppLockActive", defaultValue: false)
    var isAppLockActive: Bool
    @UserDefault("appLockKey", defaultValue: "")
    var appLockKey: String
    @UserDefault("isBiometricsEnabled", defaultValue: true)
    var isBiometricsEnabled: Bool
    
    /// — Clear clipboard after delay option (never by default)
    @UserDefault("clearClipboardDelay", defaultValue: pwgClearClipboard.never.rawValue)
    @objc var clearClipboardDelay: Int

    @UserDefault("memoryCache", defaultValue: 32)   // 4 x min = 32 MB
    @objc var memoryCache: Int

    @UserDefault("diskCache", defaultValue: 512)    // 4 x min = 512 MB
    @objc var diskCache: Int
    
    /// - Remember which help views were watched
    @UserDefault("didWatchHelpViews", defaultValue: 0b00000000_00000000)
    @objc var didWatchHelpViews: UInt16
    
    /// - Request help for translating Piwigo once a month max
    let kPiwigoOneMonth: TimeInterval = 31.0 * 24.0 * 60.0 * 60.0     // i.e. 31 days
    @UserDefault("dateOfLastTranslationRequest", defaultValue: Date().timeIntervalSinceReferenceDate)
    @objc var dateOfLastTranslationRequest: TimeInterval
    
    
    // MARK: - Vars in UserDefaults / App Group
    // Application variables stored in UserDefaults / App Group
    /// - None

    
    // MARK: - Vars in Memory
    // Application variables kept in memory
    /// - Directionality of the language in the user interface of the app?
    @objc var isAppLanguageRTL = (UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft)
    
    /// - Is system dark palette active?
    @objc var isSystemDarkModeActive = false
    
    /// - Check for haptics compatibility at the app’s launch
    var supportsHaptics: Bool = false

    /// - App Lock status
    var isAppUnlocked: Bool = false
    
    /// - Number of albums in cache (excepted smart albums) calculated before connecting other scenes
    var nberOfAlbumsInCache: Int = 0
    
    /// - Flag informing the scene delegate that the user asked to logout
    var isLoggingOut: Bool = false
}
