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
    case `default`  = "Default Configuration"
    case `external` = "External Display"
}

@available(iOS 13.0, *)
enum ActivityType: String {
    case album = "piwigo.album"
    case external = "piwigo.external"

    func sceneConfiguration() -> UISceneConfiguration {
        switch self {
        case .album:        // Album/images collection view
            let sceneConfig = UISceneConfiguration(name: SceneConfiguration.default.rawValue,
                                                   sessionRole: .windowApplication)
            sceneConfig.delegateClass = SceneDelegate.self
            sceneConfig.storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
            return sceneConfig
        
        case .external:     // Album/images collection view w/o interaction
            if #available(iOS 16.0, *) {
                let sceneConfig = UISceneConfiguration(name: SceneConfiguration.external.rawValue,
                                                       sessionRole: .windowExternalDisplayNonInteractive)
                sceneConfig.delegateClass = ExternalDisplaySceneDelegate.self
                sceneConfig.storyboard = UIStoryboard(name: "LaunchScreenExternal", bundle: nil)
                return sceneConfig
            } else {
                // Fallback on earlier versions
                let sceneConfig = UISceneConfiguration(name: SceneConfiguration.external.rawValue,
                                                       sessionRole: .windowExternalDisplay)
                sceneConfig.delegateClass = ExternalDisplaySceneDelegate.self
                sceneConfig.storyboard = UIStoryboard(name: "LaunchScreenExternal", bundle: nil)
                return sceneConfig
            }
        }
    }

    func userActivity(userInfo: [String: Any] = [:]) -> NSUserActivity {
      let activity = NSUserActivity(activityType: self.rawValue)
      activity.userInfo = userInfo
      return activity
    }
}
