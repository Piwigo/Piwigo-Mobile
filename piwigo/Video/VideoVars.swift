//
//  VideoVars.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 06/08/2023.
//  Copyright © 2023 Piwigo.org. All rights reserved.
//

import Foundation
import piwigoKit

class VideoVars: NSObject {
    
    // Singleton
    static let shared = VideoVars()
    
    // Remove deprecated stored objects if needed
    override init() {
        // Deprecated data?
//        if let _ = UserDefaults.dataSuite.object(forKey: "isPlayerMuted") {
//            UserDefaults.dataSuite.removeObject(forKey: "isPlayerMuted")
//        }
    }
    
    // MARK: - Vars in UserDefaults / Standard
    /// - Remembers auto-play option for device display
    @UserDefault("defaultPlayerRate", defaultValue: 1.0)
    var defaultPlayerRate: Float
    /// - Remembers last selected video player mute option
    @UserDefault("isMuted", defaultValue: false)
    var isMuted: Bool

    
    // MARK: - Vars in UserDefaults / App Group
    // Image variables stored in UserDefaults / App Group
    /// - None


    // MARK: - Vars in Memory
    // Image variables kept in memory
    /// - None
}
