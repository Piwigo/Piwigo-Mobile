//
//  UIVars.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 18/07/2026.
//

import Foundation
import PwgKit

// Mark UIVars as Sendable since Apple documents UserDefaults as thread-safe
public class UIVars: @unchecked Sendable {
    
    // Singleton
    public static let shared = UIVars()
    
    // Remove deprecated stored objects if needed
    init() {
        // Deprecated data?
//        if let _ = UserDefaults.standard.object(forKey: "couldNotMigrateCoreDataStore") {
//            UserDefaults.standard.removeObject(forKey: "couldNotMigrateCoreDataStore")
//        }
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
    }
    
    // MARK: - Vars in UserDefaults / Standard
    // Variables stored in UserDefaults / Standard
    /// None
    
    
    // MARK: - Vars in UserDefaults / App Group
    // Variables stored in UserDefaults / App Group
    /// - App and extensions adopt a permanent light/dark mode or switch automatically with system
    @UserDefault("isDarkPaletteActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isDarkPaletteActive: Bool
    @UserDefault("switchPaletteAutomatically", defaultValue: true, userDefaults: UserDefaults.dataSuite)
    public var switchPaletteAutomatically: Bool
    @UserDefault("isDarkPaletteModeActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isDarkPaletteModeActive: Bool
    @UserDefault("isLightPaletteModeActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isLightPaletteModeActive: Bool

    /// - App Lock option
    @UserDefault("isAppLockActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isAppLockActive: Bool
    @UserDefault("appLockKey", defaultValue: "", userDefaults: UserDefaults.dataSuite)
    public var appLockKey: String
    @UserDefault("isBiometricsEnabled", defaultValue: true, userDefaults: UserDefaults.dataSuite)
    public var isBiometricsEnabled: Bool
    
    /// - Date of the last successful unlock, refreshed by the share extension
    ///   just before it opens the main app, so that the app does not ask again.
    @UserDefault("dateOfLastUnlock", defaultValue: Date.distantPast.timeIntervalSinceReferenceDate, userDefaults: .dataSuite)
    public var dateOfLastUnlock: TimeInterval
    
    
    // MARK: - Vars in Memory
    // Variables kept in memory
    /// - Is system dark palette active?
    public var isSystemDarkModeActive = false
}
