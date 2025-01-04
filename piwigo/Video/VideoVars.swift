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
        if let _ = UserDefaults.standard.object(forKey: "defaultPlayerRate") {
            UserDefaults.standard.removeObject(forKey: "defaultPlayerRate")
        }
//        if let _ = UserDefaults.dataSuite.object(forKey: "test") {
//            UserDefaults.dataSuite.removeObject(forKey: "test")
//        }
    }
    
    // MARK: - Vars in UserDefaults / Standard
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
