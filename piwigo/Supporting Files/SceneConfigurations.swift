//
//  SceneConfigurations.swift
//  piwigo
//
//  Created by Eddy Lelièvre-Berna on 23/04/2022.
//  Copyright © 2022 Piwigo.org. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
enum SceneConfiguration: String {
    case `default` = "Default Configuration"
}

@available(iOS 13.0, *)
enum ActivityType: String {
    case album = "piwigo.album"

    func sceneConfiguration() -> UISceneConfiguration {
        switch self {
        case .album:    // Album/images collection view
            return UISceneConfiguration(name: SceneConfiguration.default.rawValue,
                                        sessionRole: .windowApplication)
        }
    }

    func userActivity(userInfo: [String: Any] = [:]) -> NSUserActivity {
      let activity = NSUserActivity(activityType: self.rawValue)
      activity.userInfo = userInfo
      return activity
    }
}
