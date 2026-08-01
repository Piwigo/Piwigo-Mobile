//
//  NetworkVars.swift
//  PwgAPIKit
//
//  Created by Eddy Lelièvre-Berna on 24/05/2021.
//  Copyright © 2021 Piwigo.org. All rights reserved.
//
// A UserDefaultsManager subclass that persists network settings.

import Foundation
import SystemConfiguration
import PwgKit

// Mark NetworkVars as Sendable since Apple documents UserDefaults as thread-safe
// and pwgUserStatus is Sendable
public final class NetworkVars: @unchecked Sendable {
    
    // Singleton
    public static let shared = NetworkVars()
    
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
    // Network variables stored in UserDefaults / Standard
    /// - none
    

    // MARK: - Vars in UserDefaults / App Group
    // Network variables stored in UserDefaults / App Group
    /// - pwg.users.api_key.revoke method available, false by default (available since Piwigo 16)
    @UserDefault("usesAPIkeys", defaultValue: false, userDefaults: UserDefaults.dataSuite)
    public var usesAPIkeys: Bool
    
    /// - API methods which are prohibited when making requests with an API key
    @UserDefault("apiKeysProhibitedMethods", defaultValue: Set([pwgSessionLogin, pwgSessionLogout]), userDefaults: UserDefaults.dataSuite)
    public var apiKeysProhibitedMethods: Set<String>
    
    
    // MARK: - Vars in Memory
    // Network variables kept in memory
    /// - none
}
