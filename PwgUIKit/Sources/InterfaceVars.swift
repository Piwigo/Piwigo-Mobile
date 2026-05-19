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
    /// - App color palette (adopts light/dark modes or not)
    @UserDefault("isDarkPaletteActive", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var isDarkPaletteActive: Bool
}
