//
//  AppVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 01/06/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class AppVars: NSObject {
    
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
    @objc static var isDarkPaletteActive: Bool
    @UserDefault("switchPaletteAutomatically", defaultValue: true)
    @objc static var switchPaletteAutomatically: Bool
    @UserDefault("switchPaletteThreshold", defaultValue: 40)
    @objc static var switchPaletteThreshold: Int
    @UserDefault("isDarkPaletteModeActive", defaultValue: false)
    @objc static var isDarkPaletteModeActive: Bool
    @UserDefault("isLightPaletteModeActive", defaultValue: false)
    @objc static var isLightPaletteModeActive: Bool
    
    /// - Memory cache size
    static let kPiwigoMemoryCacheInc = 8            // Slider increment
    static let kPiwigoMemoryCacheMin = 0            // Minimum size
    static let kPiwigoMemoryCacheMax = 256          // Maximum size
    @UserDefault("memoryCache", defaultValue: 32)   // 4 x min = 32 MB
    @objc static var memoryCache: Int

    /// - Disk cache size
    static let kPiwigoDiskCacheInc   = 64;          // Slider increment
    static let kPiwigoDiskCacheMin   = 128;         // Minimum size
    static let kPiwigoDiskCacheMax   = 2048;        // Maximum size
    @UserDefault("diskCache", defaultValue: 512)    // 4 x min = 512 MB
    @objc static var diskCache: Int
    
    /// - Remember which help views were watched
    @UserDefault("didWatchHelpViews", defaultValue: 0b00000000_00000000)
    @objc static var didWatchHelpViews: UInt16
    
    /// - Request help for translating Piwigo once a month max
    static let kPiwigoOneMonth = (TimeInterval)(31 * 24 * 60 * 60)     // i.e. 31 days
    @UserDefault("dateOfLastTranslationRequest", defaultValue: Date().timeIntervalSinceReferenceDate)
    @objc static var dateOfLastTranslationRequest: TimeInterval
    
    
    // MARK: - Vars in UserDefaults / App Group
    // Application variables stored in UserDefaults / App Group
    /// - None

    
    // MARK: - Vars in Memory
    // Application variables kept in memory
    /// - Directionality of the language in the user interface of the app?
    @objc static var isAppLanguageRTL = (UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft)
    
    /// - Is system dark palette active?
    @objc static var isSystemDarkModeActive = false
}
