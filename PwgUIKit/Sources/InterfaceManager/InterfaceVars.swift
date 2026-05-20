//
//  InterfaceVars.swift
//  PwgUIKit
//
//  Created by Eddy Lelièvre-Berna on 19/05/2026.
//
// A UserDefaultsManager subclass that persists interface settings.

import Foundation
import PwgKit

// Mark InterfaceVars as Sendable since Apple documents UserDefaults as thread-safe
// and pwgUserStatus is Sendable
public final class InterfaceVars: @unchecked Sendable {
    
    // Singleton
    public static let shared = InterfaceVars()
    
    // Remove deprecated stored objects if needed
    init() {
        // Deprecated data?
//        if let _ = UserDefaults.standard.object(forKey: "test") {
//            UserDefaults.standard.removeObject(forKey: "test")
//        }
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
    }
    
    
    // MARK: - Vars in UserDefaults / Standard
    // Server variables stored in UserDefaults / Standard
    /// - None
    

    // MARK: - Vars in UserDefaults / App Group
    // Network variables stored in UserDefaults / App Group
    /// - App and extensions adopt a permanent light/dark mode or switch automatically with system
    @UserDefault("isDarkPaletteActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isDarkPaletteActive: Bool
    @UserDefault("switchPaletteAutomatically", defaultValue: true, userDefaults: UserDefaults.dataSuite)
    public var switchPaletteAutomatically: Bool
    @UserDefault("isDarkPaletteModeActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isDarkPaletteModeActive: Bool
    @UserDefault("isLightPaletteModeActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isLightPaletteModeActive: Bool
    
    
    // MARK: - Vars in Memory
    // Application variables kept in memory
    /// - Is system dark palette active?
    public var isSystemDarkModeActive = false
}
